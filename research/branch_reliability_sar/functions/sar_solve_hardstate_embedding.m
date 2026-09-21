function Sol = sar_solve_hardstate_embedding(cfg, target)
%SAR_SOLVE_HARDSTATE_EMBEDDING Deterministic bounded inverse mapping.
%
% CRITICAL DESIGN RULE:
% The objective uses only physical-to-parameter mismatch and physical
% plausibility penalties. It NEVER evaluates G0, Neighbor-3, Proposed, or
% any branch-success label. Therefore a later branch rescue remains a true
% falsification test rather than an optimized outcome.

starts = cfg.stageB2.u_starts;
ns = size(starts,1);

best_f = inf;
best_u = [];
best_C = [];
start_summary = nan(ns,4);

opts = optimset('Display','off', ...
    'MaxIter',cfg.stageB2.fminsearch_max_iter, ...
    'MaxFunEvals',cfg.stageB2.fminsearch_max_fun_evals, ...
    'TolX',cfg.stageB2.fminsearch_tolx, ...
    'TolFun',cfg.stageB2.fminsearch_tolfun);

for i = 1:ns
    u0 = starts(i,:);
    [u,fval,exitflag,out] = fminsearch(@objective,u0,opts);
    C = evaluate_u(u);
    start_summary(i,:) = [i,fval,exitflag,out.funcCount];
    if fval < best_f
        best_f = fval;
        best_u = u;
        best_C = C;
    end
end

Sol = struct();
Sol.best_objective = best_f;
Sol.best_u = best_u;
Sol.candidate = best_C;
Sol.start_summary = array2table(start_summary, ...
    'VariableNames',{'start_id','objective','exitflag','func_count'});
Sol.target = target;
Sol.errors = compute_errors(best_C,target,cfg);

    function f = objective(u)
        C = evaluate_u(u);
        E = compute_errors(C,target,cfg);

        f = E.beta_s_over_W^2 + E.beta_w_over_W^2 + ...
            E.nu_s_scaled^2 + E.nu_w_scaled^2 + ...
            0.5*E.nu_pair_scaled^2;

        % Soft model-consistency penalties.
        if C.fit_s.phase_fit_nrmse > cfg.stageB2.max_fit_nrmse_soft
            z=(C.fit_s.phase_fit_nrmse-cfg.stageB2.max_fit_nrmse_soft)/ ...
                cfg.stageB2.max_fit_nrmse_soft;
            f=f+4*z^2;
        end
        if C.fit_w.phase_fit_nrmse > cfg.stageB2.max_fit_nrmse_soft
            z=(C.fit_w.phase_fit_nrmse-cfg.stageB2.max_fit_nrmse_soft)/ ...
                cfg.stageB2.max_fit_nrmse_soft;
            f=f+4*z^2;
        end

        if C.strong_minmax < cfg.stageB2.min_amp_ratio_soft
            z=(cfg.stageB2.min_amp_ratio_soft-C.strong_minmax)/ ...
                cfg.stageB2.min_amp_ratio_soft;
            f=f+2*z^2;
        end
        if C.weak_minmax < cfg.stageB2.min_amp_ratio_soft
            z=(cfg.stageB2.min_amp_ratio_soft-C.weak_minmax)/ ...
                cfg.stageB2.min_amp_ratio_soft;
            f=f+2*z^2;
        end

        % Hard-ish physical geometry penalties.
        sep = C.pair_center_separation_m;
        if sep < cfg.stageB2.min_pair_center_separation_m
            z=(cfg.stageB2.min_pair_center_separation_m-sep)/ ...
                cfg.stageB2.min_pair_center_separation_m;
            f=f+50*z^2;
        end
        bx=max(abs(C.body_xy_m(:,1)));
        by=max(abs(C.body_xy_m(:,2)));
        if bx > cfg.stageB2.max_abs_body_x_m
            f=f+50*((bx-cfg.stageB2.max_abs_body_x_m)/5)^2;
        end
        if by > cfg.stageB2.max_abs_body_y_m
            f=f+50*((by-cfg.stageB2.max_abs_body_y_m)/3)^2;
        end

        % Weak regularization toward the Wang-anchored Stage-A motion.
        Adeg = C.p.yaw_amplitude_rad*180/pi;
        f=f+cfg.stageB2.reg_motion_weight*((Adeg-19)/10)^2;
        f=f+cfg.stageB2.reg_motion_weight*((C.p.yaw_period_s-14.2)/6)^2;
        f=f+cfg.stageB2.reg_y_offset_weight*(C.p.common_y_offset_m/8)^2;
    end

    function C = evaluate_u(u)
        p = decode_u(u,cfg.stageB2.bounds);
        C = sar_hardstate_candidate_metrics(cfg,p);
    end

end

function p = decode_u(u,B)
p = struct();
p.x_strong_center_m = map_bound(u(1),B.x_strong_center_m);
p.x_weak_center_m   = map_bound(u(2),B.x_weak_center_m);
p.common_y_offset_m = map_bound(u(3),B.common_y_offset_m);
p.yaw_amplitude_rad = map_bound(u(4),B.yaw_amplitude_deg)*pi/180;
p.yaw_period_s      = map_bound(u(5),B.yaw_period_s);
p.yaw_phase0_rad    = map_bound(u(6),B.yaw_phase0_rad);
end

function x = map_bound(u,b)
u=max(min(u,40),-40);
s=1/(1+exp(-u));
x=b(1)+(b(2)-b(1))*s;
end

function E = compute_errors(C,target,cfg)
W=cfg.stageB2.beta_scale_rad;
E=struct();
E.beta_s_rad=C.fit_s.beta_rad-target.beta_s_rad;
E.beta_w_rad=C.fit_w.beta_rad-target.beta_w_rad;
E.beta_s_over_W=E.beta_s_rad/W;
E.beta_w_over_W=E.beta_w_rad/W;

% The old DenseRisk eta is a fractional-bin coordinate around an integer
% DFT branch. Match fractional offset AND require the two physical
% components to share the same absolute branch neighborhood.
E.nu_s_frac_error_bins=frac_bin_error(C.fit_s.nu_bins,target.eta_bins);
E.nu_w_frac_error_bins=frac_bin_error(C.fit_w.nu_bins,target.eta_bins);
E.nu_pair_separation_bins=periodic_bin_distance(C.fit_s.nu_bins,C.fit_w.nu_bins,C.N);
E.nu_s_scaled=E.nu_s_frac_error_bins/cfg.stageB2.nu_frac_scale_bins;
E.nu_w_scaled=E.nu_w_frac_error_bins/cfg.stageB2.nu_frac_scale_bins;
E.nu_pair_scaled=E.nu_pair_separation_bins/cfg.stageB2.nu_pair_separation_scale_bins;
end

function e = frac_bin_error(a,b)
e=abs(mod((a-b)+0.5,1)-0.5);
end

function d = periodic_bin_distance(a,b,N)
d=abs(mod((a-b)+N/2,N)-N/2);
end
