function results = exp09_pa5b_projection_error_decomposition()
% EXP009 / PA5B
% Corrected complex-LS replay, projection-error identity validation,
% and subtraction-accuracy tolerance map.
%
% IMPORTANT CORRECTION:
% For MATLAB row vectors and x ~= c*h,
%
%   c_correct = (x*h')/(h*h')
%
% because ' is conjugate transpose.
%
% PA5 used c_legacy=(h*x')/(h*h'), which is generally conj(c_correct).
% PA5B therefore treats PA5 quantitative G2/G3 numbers as provisional and
% explicitly compares legacy vs corrected results before new claims.
%
% Exact corrected projection model:
%
%   r = x - P_h x,       x = s+w
%   e = r-w = (I-P_h)s - P_h w
%
% The two terms are orthogonal, so:
%
%   ||e||^2/||w||^2 =
%       (1-rho_sh^2)/r_A^2 + rho_wh^2
%
% where r_A=A_w/A_s.
%
% Run:
%   results = exp09_pa5b_projection_error_decomposition;

cfg = config_exp09_pa5b_projection_error_decomposition();

%% Output path
this_dir = fileparts(mfilename('fullpath'));
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.output_dir)
    out_path = fullfile(paper_root,'results','exp09_physical_validation', ...
        'exp09_pa5b_projection_error_decomposition');
else
    out_path = cfg.output_dir;
end
if ~exist(out_path,'dir'), mkdir(out_path); end

%% Physical constants
lambda = cfg.c/cfg.fc_hz;
R0 = cfg.platform_height_m*cfg.slant_range_factor;
beamwidth = cfg.beamwidth_scale*lambda/cfg.antenna_length_m;

vw = cfg.weak_velocity_mps;
[~,~,Kw] = residual_rates(vw,R0,lambda,cfg);
aw = Kw/cfg.prf_hz^2;
beta_w = atan(aw);

modes = ["Paper1s","BeamDerived"];
Nlist = [round(cfg.prf_hz*cfg.paper_aperture_time_s), ...
         round(cfg.prf_hz*(R0*beamwidth/cfg.platform_velocity_mps))];
Ttarget = [cfg.paper_aperture_time_s, ...
           R0*beamwidth/cfg.platform_velocity_mps];

%% Intrinsic weak-response width per aperture
width_rows = {};
Wstore = struct();

for ia = 1:2
    mode = modes(ia);
    N = max(32,Nlist(ia));
    maxlag = max(2,min(N-2,round(cfg.max_lag_fraction*N)));

    bg = linspace(beta_w-cfg.width_grid_halfspan_rad, ...
                  beta_w+cfg.width_grid_halfspan_rad, ...
                  cfg.width_grid_points).';

    w0 = lfm_atom(N,1,aw,0,0);
    Rww = frac_pair(w0,w0,bg,maxlag,cfg);
    Pw = sum(abs(Rww).^2,2);
    W = width3db(bg,Pw,beta_w);

    width_rows(end+1,:) = {char(mode),N,Ttarget(ia),(N-1)/cfg.prf_hz,maxlag,W}; %#ok<AGROW>
    Wstore.(char(mode)) = struct('N',N,'maxlag',maxlag,'W',W);
end

width_table = cell2table(width_rows,'VariableNames', ...
    {'aperture_mode','azimuth_samples','target_aperture_time_s', ...
     'actual_observation_time_s','max_frac_lag','weak_3db_width_beta_rad'});
writetable(width_table,fullfile(out_path,'pa5b_intrinsic_width_calibration.csv'));

%% Corrected PA5 replay and exact identity validation
rows = {};
sides = ["LowV","HighV"];

for ia = 1:2
    mode = modes(ia);
    N = Wstore.(char(mode)).N;
    maxlag = Wstore.(char(mode)).maxlag;
    W = Wstore.(char(mode)).W;

    w0 = lfm_atom(N,1,aw,0,0);

    for idv = 1:numel(cfg.delta_velocity_mps)
        dv = cfg.delta_velocity_mps(idv);

        for iside = 1:2
            side = sides(iside);
            if side=="LowV", vs = vw-dv; else, vs = vw+dv; end

            [~,~,Ks] = residual_rates(vs,R0,lambda,cfg);
            as = Ks/cfg.prf_hz^2;
            beta_s = atan(as);
            sep = abs(beta_s-beta_w);
            Gamma = sep/W;
            regime = regime_label(Gamma,cfg);

            bg = scenario_grid(beta_w,beta_s,W,cfg);
            s0 = lfm_atom(N,1,as,0,0);

            Rss = frac_pair(s0,s0,bg,maxlag,cfg);
            Rww = frac_pair(w0,w0,bg,maxlag,cfg);
            Rsw = frac_pair(s0,w0,bg,maxlag,cfg);
            Rws = frac_pair(w0,s0,bg,maxlag,cfg);

            Es = real(s0*s0');
            cache = containers.Map('KeyType','char','ValueType','any');

            for ir = 1:numel(cfg.weak_to_strong_ratio)
                rA = cfg.weak_to_strong_ratio(ir);

                for ip = 1:numel(cfg.relative_phase_rad)
                    phi = cfg.relative_phase_rad(ip);
                    cw = rA*exp(1j*phi);
                    x = s0 + cw*w0;
                    wtrue = cw*w0;

                    % G1 pre-removal topology
                    R1 = Rss + abs(cw)^2*Rww + conj(cw)*Rsw + cw*Rws;
                    P1 = sum(abs(R1).^2,2);
                    peaks = local_peaks(bg,normcurve(P1),cfg.min_peak_prominence_fraction);
                    [pre_found,~,~] = associate(peaks,beta_w,sep,W,cfg);
                    hidden = ~pre_found;

                    % Practical strong estimate = global FrAc maximum
                    [~,ihat] = max(P1);
                    beta_hat = bg(ihat);
                    ahat = tan(beta_hat);
                    esterr = (beta_hat-beta_s)/W;

                    % ---------- G2: oracle strong parameter ----------
                    c2 = (x*s0')/max(Es,cfg.small_norm_floor);
                    c2old = (s0*x')/max(Es,cfg.small_norm_floor);

                    r2 = x-c2*s0;
                    r2old = x-c2old*s0;

                    e2 = norm(r2-wtrue)/max(norm(wtrue),cfg.small_norm_floor);
                    e2old = norm(r2old-wtrue)/max(norm(wtrue),cfg.small_norm_floor);

                    Rhx2 = Rss + conj(cw)*Rsw; % B(s,x)
                    Rxh2 = Rss + cw*Rws;       % B(x,s)

                    R2 = R1-c2*Rhx2-conj(c2)*Rxh2+abs(c2)^2*Rss;
                    R2old = R1-c2old*Rhx2-conj(c2old)*Rxh2+abs(c2old)^2*Rss;

                    g2 = weak_global(bg,sum(abs(R2).^2,2),beta_w,W,cfg);
                    g2old = weak_global(bg,sum(abs(R2old).^2,2),beta_w,W,cfg);

                    % ---------- G3: practical estimated strong ----------
                    key = sprintf('i%d',ihat);
                    if isKey(cache,key)
                        C = cache(key);
                    else
                        h = lfm_atom(N,1,ahat,0,0);
                        C = struct();
                        C.h = h;
                        C.Rhs = frac_pair(h,s0,bg,maxlag,cfg);
                        C.Rhw = frac_pair(h,w0,bg,maxlag,cfg);
                        C.Rsh = frac_pair(s0,h,bg,maxlag,cfg);
                        C.Rwh = frac_pair(w0,h,bg,maxlag,cfg);
                        C.Rhh = frac_pair(h,h,bg,maxlag,cfg);
                        cache(key) = C;
                    end

                    h = C.h;
                    Eh = real(h*h');

                    c3 = (x*h')/max(Eh,cfg.small_norm_floor);       % corrected
                    c3old = (h*x')/max(Eh,cfg.small_norm_floor);    % PA5 legacy

                    r3 = x-c3*h;
                    r3old = x-c3old*h;

                    e3 = norm(r3-wtrue)/max(norm(wtrue),cfg.small_norm_floor);
                    e3old = norm(r3old-wtrue)/max(norm(wtrue),cfg.small_norm_floor);

                    Rhx = C.Rhs + conj(cw)*C.Rhw;
                    Rxh = C.Rsh + cw*C.Rwh;

                    R3 = R1-c3*Rhx-conj(c3)*Rxh+abs(c3)^2*C.Rhh;
                    R3old = R1-c3old*Rhx-conj(c3old)*Rxh+abs(c3old)^2*C.Rhh;

                    g3 = weak_global(bg,sum(abs(R3).^2,2),beta_w,W,cfg);
                    g3old = weak_global(bg,sum(abs(R3old).^2,2),beta_w,W,cfg);

                    % ---------- exact projection identity ----------
                    rho_sh = abs(s0*h')/max(norm(s0)*norm(h),cfg.small_norm_floor);
                    rho_wh = abs(w0*h')/max(norm(w0)*norm(h),cfg.small_norm_floor);

                    leak_sq = max(1-rho_sh^2,0)/rA^2;
                    weakloss_sq = rho_wh^2;
                    epred = sqrt(leak_sq+weakloss_sq);
                    iderr = abs(epred-e3);

                    denom = leak_sq+weakloss_sq;
                    if denom>0, leakfrac=leak_sq/denom; else, leakfrac=0; end

                    e2pred = abs(s0*w0')/max(norm(s0)*norm(w0),cfg.small_norm_floor);

                    rows(end+1,:) = {char(mode),N,dv,char(side),vs,Gamma,char(regime), ...
                        rA,phi,double(hidden),beta_s,beta_hat,esterr, ...
                        rho_sh,rho_wh,leak_sq,weakloss_sq,leakfrac, ...
                        epred,e3,iderr,e2,e2old,e2pred,e3old, ...
                        double(hidden && g2),double(hidden && g2old), ...
                        double(hidden && g3),double(hidden && g3old)}; %#ok<AGROW>
                end
            end
        end
    end
end

T = cell2table(rows,'VariableNames', ...
    {'aperture_mode','azimuth_samples','delta_velocity_mps','strong_velocity_side', ...
     'strong_velocity_mps','Gamma_sep_over_width','Gamma_regime', ...
     'weak_to_strong_ratio','relative_phase_rad','pre_hidden', ...
     'beta_strong_true_rad','beta_strong_hat_rad','strong_est_error_over_width', ...
     'rho_strong_hat','rho_weak_hat','strong_leak_term_sq','weak_projection_term_sq', ...
     'strong_leak_error_fraction','predicted_practical_error_ratio', ...
     'measured_practical_error_ratio_correctLS','identity_abs_error', ...
     'measured_oracle_error_ratio_correctLS','measured_oracle_error_ratio_legacyLS', ...
     'predicted_oracle_error_ratio','measured_practical_error_ratio_legacyLS', ...
     'oracle_rescue_correctLS','oracle_rescue_legacyLS', ...
     'practical_rescue_correctLS','practical_rescue_legacyLS'});
writetable(T,fullfile(out_path,'pa5b_trial_validation.csv'));

%% Summaries
identity = identity_summary(T,cfg);
audit = legacy_audit(T);
contrast = contrast_summary(T);
regime = regime_summary(T);

writetable(identity,fullfile(out_path,'pa5b_identity_validation_summary.csv'));
writetable(audit,fullfile(out_path,'pa5b_legacy_vs_correct_audit.csv'));
writetable(contrast,fullfile(out_path,'pa5b_corrected_contrast_recovery.csv'));
writetable(regime,fullfile(out_path,'pa5b_corrected_regime_recovery.csv'));

%% Imposed-mismatch transfer and tolerance
[Ttol,Stol] = tolerance_map(cfg,Wstore,lambda,R0,beta_w,aw);
writetable(Ttol,fullfile(out_path,'pa5b_tolerance_trials.csv'));
writetable(Stol,fullfile(out_path,'pa5b_tolerance_summary.csv'));

safe = safety_summary(T,Ttol,cfg);
writetable(safe,fullfile(out_path,'pa5b_practical_tolerance_safety.csv'));

decision = decision_summary(identity,audit,safe,cfg);
writetable(decision,fullfile(out_path,'pa5b_decision_summary.csv'));

write_summary(out_path,cfg,lambda,R0,width_table,identity,audit,contrast,regime,Stol,safe,decision);
make_figures(out_path,cfg,T,audit,contrast,Ttol,Stol,safe);

results = struct('cfg',cfg,'lambda',lambda,'R0',R0,'width_table',width_table, ...
    'trial_table',T,'identity_summary',identity,'audit_summary',audit, ...
    'contrast_summary',contrast,'regime_summary',regime, ...
    'tolerance_trials',Ttol,'tolerance_summary',Stol, ...
    'safety_summary',safe,'decision_summary',decision);

save(fullfile(out_path,'exp09_pa5b_results.mat'),'results','-v7.3');

fprintf('\n=== EXP009 PA5B ===\n');
disp(identity); disp(audit); disp(Stol); disp(safe); disp(decision);
fprintf('Saved to:\n%s\n',out_path);
end

%% ============================== helpers ================================
function [KA,KS,Kres] = residual_rates(v,R0,lambda,cfg)
V = cfg.platform_velocity_mps;
KA = -2*(V-v).^2/(lambda*R0);
KS = 2*V^2/(lambda*R0);
Kres = KS.^2./(KA-KS)+KS;
end

function x = lfm_atom(N,A,a,b,phi)
m = 0:N-1;
x = A*exp(1j*2*pi*(0.5*a*m.^2+b*m)+1j*phi);
x = x(:).';
end

function R = frac_pair(xl,xr,bg,maxlag,cfg)
xl=xl(:).'; xr=xr(:).'; N=numel(xl);
nfft=max(2048,2^nextpow2(cfg.frac_fft_oversample*N));
f=(-nfft/2:nfft/2-1).'/nfft;
tb=tan(bg(:));
R=complex(zeros(numel(bg),maxlag));
for k=1:maxlag
    z=xl(1+k:end).*conj(xr(1:end-k));
    Z=fftshift(fft(z,nfft)).';
    R(:,k)=interp1(f,Z,k*tb,'linear',0)/numel(z);
end
end

function W = width3db(bg,P,b0)
P=real(P(:)); [~,i0]=min(abs(bg-b0));
hw=max(5,round(.2*numel(bg))); i1=max(1,i0-hw); i2=min(numel(bg),i0+hw);
[~,j]=max(P(i1:i2)); ip=i1+j-1; lev=P(ip)/2;
il=ip; while il>1 && P(il)>=lev, il=il-1; end
ir=ip; while ir<numel(P) && P(ir)>=lev, ir=ir+1; end
if il==1 || ir==numel(P), W=NaN; else, W=bg(ir)-bg(il); end
end

function bg = scenario_grid(bw,bs,W,cfg)
sep=abs(bs-bw);
step=min(cfg.beta_step_width_fraction*W, ...
         cfg.beta_step_separation_fraction*max(sep,eps));
step=max(step,cfg.beta_step_min_width_fraction*W);
lo=min(bw,bs)-cfg.beta_margin_widths*W;
hi=max(bw,bs)+cfg.beta_margin_widths*W;
bg=linspace(lo,hi,ceil((hi-lo)/step)+1).';
end

function s = regime_label(G,cfg)
if G<cfg.gamma_unresolved_max, s="Unresolved";
elseif G<cfg.gamma_partial_max, s="Partial";
else, s="ResolvedCandidate"; end
end

function y = normcurve(y)
y=real(y(:)); m=max(y); if m>0, y=y/m; end
end

function p = local_peaks(bg,P,pfrac)
P=P(:);
idx=find(P(2:end-1)>P(1:end-2) & P(2:end-1)>=P(3:end))+1;
if isempty(idx), [~,idx]=max(P); end
pr=zeros(size(idx));
for j=1:numel(idx)
    ii=idx(j);
    pr(j)=P(ii)-max(min(P(1:ii)),min(P(ii:end)));
end
rg=max(P)-min(P);
if rg>0, keep=pr>=pfrac*rg; else, keep=true(size(pr)); end
idx=idx(keep); pr=pr(keep);
if isempty(idx), [~,idx]=max(P); pr=max(P)-min(P); end
p.beta=bg(idx); p.prominence=pr(:);
end

function [found,bp,prom] = associate(p,btrue,sep,W,cfg)
rad=max(cfg.peak_association_fraction_of_separation*sep, ...
        cfg.peak_association_min_width_fraction*W);
d=abs(p.beta-btrue); ii=find(d<=rad);
if isempty(ii), found=false; bp=NaN; prom=NaN; return; end
[~,o]=sortrows([d(ii),-p.prominence(ii)],[1 2]); j=ii(o(1));
found=true; bp=p.beta(j); prom=p.prominence(j);
end

function ok = weak_global(bg,P,bw,W,cfg)
[~,i]=max(real(P(:)));
ok=abs(bg(i)-bw)<=cfg.post_weak_global_tolerance_widths*W;
end

function S = identity_summary(T,cfg)
modes=unique(string(T.aperture_mode),'stable'); rows={};
for i=1:numel(modes)
    M=T(string(T.aperture_mode)==modes(i),:);
    e=M.identity_abs_error; e=e(isfinite(e));
    eo=abs(M.measured_oracle_error_ratio_correctLS-M.predicted_oracle_error_ratio);
    eo=eo(isfinite(eo));
    rows(end+1,:)={char(modes(i)),height(M),median(e),max(e), ...
        double(max(e)<=cfg.identity_max_abs_error_gate),max(eo)}; %#ok<AGROW>
end
S=cell2table(rows,'VariableNames',{'aperture_mode','n','median_identity_abs_error', ...
    'max_identity_abs_error','identity_gate_pass','max_oracle_special_case_abs_error'});
end

function S = legacy_audit(T)
modes=unique(string(T.aperture_mode),'stable'); rows={};
for i=1:numel(modes)
    H=T(string(T.aperture_mode)==modes(i) & logical(T.pre_hidden),:);
    rows(end+1,:)={char(modes(i)),height(H), ...
        mean(H.oracle_rescue_correctLS),mean(H.oracle_rescue_legacyLS), ...
        mean(H.practical_rescue_correctLS),mean(H.practical_rescue_legacyLS), ...
        mean(H.practical_rescue_correctLS)-mean(H.practical_rescue_legacyLS), ...
        median(H.measured_oracle_error_ratio_correctLS,'omitnan'), ...
        median(H.measured_oracle_error_ratio_legacyLS,'omitnan'), ...
        median(H.measured_practical_error_ratio_correctLS,'omitnan'), ...
        median(H.measured_practical_error_ratio_legacyLS,'omitnan')}; %#ok<AGROW>
end
S=cell2table(rows,'VariableNames',{'aperture_mode','n_pre_hidden', ...
    'oracle_rescue_correctLS','oracle_rescue_legacyLS', ...
    'practical_rescue_correctLS','practical_rescue_legacyLS', ...
    'practical_rescue_change_correct_minus_legacy','median_oracle_error_correctLS', ...
    'median_oracle_error_legacyLS','median_practical_error_correctLS', ...
    'median_practical_error_legacyLS'});
end

function S = contrast_summary(T)
modes=unique(string(T.aperture_mode),'stable');
rr=unique(T.weak_to_strong_ratio).'; rows={};
for i=1:numel(modes)
    for j=1:numel(rr)
        H=T(string(T.aperture_mode)==modes(i) & logical(T.pre_hidden) & ...
            abs(T.weak_to_strong_ratio-rr(j))<1e-12,:);
        rows(end+1,:)={char(modes(i)),rr(j),height(H), ...
            mean(H.oracle_rescue_correctLS),mean(H.practical_rescue_correctLS), ...
            median(H.measured_practical_error_ratio_correctLS,'omitnan'), ...
            median(H.strong_leak_error_fraction,'omitnan'), ...
            median(abs(H.strong_est_error_over_width),'omitnan')}; %#ok<AGROW>
    end
end
S=cell2table(rows,'VariableNames',{'aperture_mode','weak_to_strong_ratio','n_hidden', ...
    'oracle_rescue_correctLS','practical_rescue_correctLS', ...
    'median_practical_error_correctLS','median_strong_leak_error_fraction', ...
    'median_abs_strong_est_error_over_width'});
end

function S = regime_summary(T)
modes=unique(string(T.aperture_mode),'stable');
regs=["Unresolved","Partial","ResolvedCandidate"]; rows={};
for i=1:numel(modes)
    for j=1:numel(regs)
        M=T(string(T.aperture_mode)==modes(i) & string(T.Gamma_regime)==regs(j),:);
        H=M(logical(M.pre_hidden),:);
        if isempty(M)
            rows(end+1,:)={char(modes(i)),char(regs(j)),0,0,NaN,NaN,NaN}; %#ok<AGROW>
        else
            rows(end+1,:)={char(modes(i)),char(regs(j)),height(M),height(H), ...
                height(H)/height(M),mean(H.practical_rescue_correctLS), ...
                median(H.measured_practical_error_ratio_correctLS,'omitnan')}; %#ok<AGROW>
        end
    end
end
S=cell2table(rows,'VariableNames',{'aperture_mode','Gamma_regime','n','n_hidden', ...
    'pre_hidden_rate','practical_rescue_correctLS','median_practical_error_correctLS'});
end

function [Tall,S] = tolerance_map(cfg,Wstore,lambda,R0,bw,aw)
rows={}; modes=["Paper1s","BeamDerived"]; sides=["LowV","HighV"];
for ia=1:2
    mode=modes(ia); N=Wstore.(char(mode)).N; W=Wstore.(char(mode)).W;
    w0=lfm_atom(N,1,aw,0,0);
    for id=1:numel(cfg.delta_velocity_mps)
        dv=cfg.delta_velocity_mps(id);
        for is=1:2
            side=sides(is);
            if side=="LowV", vs=cfg.weak_velocity_mps-dv; else, vs=cfg.weak_velocity_mps+dv; end
            [~,~,Ks]=residual_rates(vs,R0,lambda,cfg);
            as=Ks/cfg.prf_hz^2; bs=atan(as); G=abs(bs-bw)/W;
            for ir=1:numel(cfg.weak_to_strong_ratio)
                rA=cfg.weak_to_strong_ratio(ir);
                s0=lfm_atom(N,1,as,0,0);
                for jd=1:numel(cfg.delta_beta_over_width)
                    dn=cfg.delta_beta_over_width(jd);
                    h=lfm_atom(N,1,tan(bs+dn*W),0,0);
                    rsh=abs(s0*h')/(norm(s0)*norm(h));
                    rwh=abs(w0*h')/(norm(w0)*norm(h));
                    L=sqrt(max(1-rsh^2,0));
                    E=sqrt(max(1-rsh^2,0)/rA^2+rwh^2);
                    rows(end+1,:)={char(mode),dv,char(side),vs,G,rA,dn,rsh,rwh,L,E}; %#ok<AGROW>
                end
            end
        end
    end
end
Tall=cell2table(rows,'VariableNames',{'aperture_mode','delta_velocity_mps', ...
    'strong_velocity_side','strong_velocity_mps','Gamma_sep_over_width', ...
    'weak_to_strong_ratio','delta_beta_over_width','rho_strong_hat','rho_weak_hat', ...
    'strong_mismatch_leakage_ratio_to_strong','predicted_error_ratio'});

sumrows={};
for ia=1:2
    for ir=1:numel(cfg.weak_to_strong_ratio)
        for it=1:numel(cfg.error_thresholds)
            vals=[];
            for id=1:numel(cfg.delta_velocity_mps)
                for is=1:2
                    M=Tall(string(Tall.aperture_mode)==modes(ia) & ...
                        Tall.delta_velocity_mps==cfg.delta_velocity_mps(id) & ...
                        string(Tall.strong_velocity_side)==sides(is) & ...
                        abs(Tall.weak_to_strong_ratio-cfg.weak_to_strong_ratio(ir))<1e-12,:);
                    vals(end+1,1)=symtol(M.delta_beta_over_width,M.predicted_error_ratio, ...
                        cfg.error_thresholds(it)); %#ok<AGROW>
                end
            end
            sumrows(end+1,:)={char(modes(ia)),cfg.weak_to_strong_ratio(ir), ...
                cfg.error_thresholds(it),median(vals),min(vals),max(vals)}; %#ok<AGROW>
        end
    end
end
S=cell2table(sumrows,'VariableNames',{'aperture_mode','weak_to_strong_ratio', ...
    'error_threshold','median_allowed_abs_beta_error_over_width', ...
    'minimum_allowed_abs_beta_error_over_width','maximum_allowed_abs_beta_error_over_width'});
end

function t = symtol(d,E,thr)
[d,o]=sort(d(:)); E=E(o); [~,i0]=min(abs(d));
if E(i0)>thr, t=0; return; end
il=i0; while il>1 && E(il-1)<=thr, il=il-1; end
ir=i0; while ir<numel(E) && E(ir+1)<=thr, ir=ir+1; end
t=min(abs(d(il)),abs(d(ir)));
end

function S = safety_summary(T,Ttol,cfg)
modes=unique(string(T.aperture_mode),'stable');
rr=unique(T.weak_to_strong_ratio).'; rows={};
for i=1:numel(modes)
    for j=1:numel(rr)
        H=T(string(T.aperture_mode)==modes(i) & logical(T.pre_hidden) & ...
            abs(T.weak_to_strong_ratio-rr(j))<1e-12,:);
        safe=false(height(H),1); tv=nan(height(H),1);
        for k=1:height(H)
            M=Ttol(string(Ttol.aperture_mode)==modes(i) & ...
                Ttol.delta_velocity_mps==H.delta_velocity_mps(k) & ...
                strcmp(Ttol.strong_velocity_side,H.strong_velocity_side{k}) & ...
                abs(Ttol.weak_to_strong_ratio-rr(j))<1e-12,:);
            tv(k)=symtol(M.delta_beta_over_width,M.predicted_error_ratio,1);
            safe(k)=abs(H.strong_est_error_over_width(k))<=tv(k);
        end
        rows(end+1,:)={char(modes(i)),rr(j),height(H), ...
            median(abs(H.strong_est_error_over_width),'omitnan'),median(tv,'omitnan'), ...
            mean(safe),median(H.measured_practical_error_ratio_correctLS,'omitnan')}; %#ok<AGROW>
    end
end
S=cell2table(rows,'VariableNames',{'aperture_mode','weak_to_strong_ratio','n_hidden', ...
    'median_abs_practical_beta_error_over_width', ...
    'median_allowed_abs_beta_error_over_width_for_E_le_1', ...
    'fraction_practical_estimates_inside_E_le_1_tolerance', ...
    'median_measured_practical_error_ratio_correctLS'});
end

function D = decision_summary(I,A,S,cfg)
modes=string(I.aperture_mode); rows={};
for i=1:numel(modes)
    Si=S(strcmp(S.aperture_mode,char(modes(i))),:);
    medsafe=median(Si.fraction_practical_estimates_inside_E_le_1_tolerance,'omitnan');
    if I.identity_gate_pass(i)==0
        branch="IDENTITY_IMPLEMENTATION_REVIEW";
    elseif medsafe<0.5
        branch="SUBTRACTION_TOLERANCE_TIGHTER_THAN_ESTIMATOR";
    elseif A.practical_rescue_correctLS(i)>=0.7 && A.median_practical_error_correctLS(i)<=0.5
        branch="CORRECTED_PRACTICAL_REMOVAL_EFFECTIVE";
    else
        branch="MIXED_TOLERANCE_AND_OPERATOR_LIMIT";
    end
    q=abs(A.practical_rescue_correctLS(i)-A.practical_rescue_legacyLS(i))>0.05 || ...
      abs(A.median_practical_error_correctLS(i)-A.median_practical_error_legacyLS(i))>0.10;
    if q, audit="PA5_QUANTITATIVE_RESULTS_REQUIRE_CORRECTION";
    else, audit="PA5_LEGACY_NUMBERS_NEAR_CORRECT"; end
    rows(end+1,:)={char(modes(i)),char(audit),medsafe,char(branch)}; %#ok<AGROW>
end
D=cell2table(rows,'VariableNames',{'aperture_mode','pa5_legacy_audit_status', ...
    'median_fraction_inside_E_le_1_tolerance','decision_branch'});
end

function write_summary(out,cfg,lambda,R0,W,I,A,C,G,ST,SF,D)
fid=fopen(fullfile(out,'summary.txt'),'w');
fprintf(fid,'EXP009 PA5B / LS Projection Error Decomposition\n');
fprintf(fid,'================================================\n\n');
fprintf(fid,'CRITICAL CORRECTION\n');
fprintf(fid,'Correct row-vector complex LS: c=(x*h'')/(h*h'').\n');
fprintf(fid,'PA5 legacy: c=(h*x'')/(h*h'').\n');
fprintf(fid,'PA5 quantitative G2/G3 values are provisional until this audit.\n\n');
fprintf(fid,'fc=%g Hz, PRF=%g Hz, lambda=%g m, R0=%g m\n\n',cfg.fc_hz,cfg.prf_hz,lambda,R0);

fprintf(fid,'Intrinsic widths\n');
for i=1:height(W)
    fprintf(fid,'%s N=%d T=%g Wbeta=%g\n',W.aperture_mode{i},W.azimuth_samples(i), ...
        W.actual_observation_time_s(i),W.weak_3db_width_beta_rad(i));
end

fprintf(fid,'\nProjection identity\n');
for i=1:height(I)
    fprintf(fid,'%s maxAbsErr=%g gate=%d oracleMaxErr=%g\n',I.aperture_mode{i}, ...
        I.max_identity_abs_error(i),I.identity_gate_pass(i), ...
        I.max_oracle_special_case_abs_error(i));
end

fprintf(fid,'\nLegacy vs corrected\n');
for i=1:height(A)
    fprintf(fid,['%s practicalRescue correct/legacy=%g/%g; ' ...
        'practicalError correct/legacy=%g/%g; oracleError correct/legacy=%g/%g\n'], ...
        A.aperture_mode{i},A.practical_rescue_correctLS(i),A.practical_rescue_legacyLS(i), ...
        A.median_practical_error_correctLS(i),A.median_practical_error_legacyLS(i), ...
        A.median_oracle_error_correctLS(i),A.median_oracle_error_legacyLS(i));
end

fprintf(fid,'\nCorrected contrast\n');
for i=1:height(C)
    fprintf(fid,'%s r=%g practical=%g error=%g leakFrac=%g medBetaErr/W=%g\n', ...
        C.aperture_mode{i},C.weak_to_strong_ratio(i),C.practical_rescue_correctLS(i), ...
        C.median_practical_error_correctLS(i),C.median_strong_leak_error_fraction(i), ...
        C.median_abs_strong_est_error_over_width(i));
end

fprintf(fid,'\nCorrected regime\n');
for i=1:height(G)
    fprintf(fid,'%s %s hidden=%g practical=%g error=%g\n',G.aperture_mode{i}, ...
        G.Gamma_regime{i},G.pre_hidden_rate(i),G.practical_rescue_correctLS(i), ...
        G.median_practical_error_correctLS(i));
end

fprintf(fid,'\nTolerance summary\n');
for i=1:height(ST)
    fprintf(fid,'%s r=%g Ethr=%g tol median/min/max=%g/%g/%g\n', ...
        ST.aperture_mode{i},ST.weak_to_strong_ratio(i),ST.error_threshold(i), ...
        ST.median_allowed_abs_beta_error_over_width(i), ...
        ST.minimum_allowed_abs_beta_error_over_width(i), ...
        ST.maximum_allowed_abs_beta_error_over_width(i));
end

fprintf(fid,'\nPractical estimator vs E<=1 tolerance\n');
for i=1:height(SF)
    fprintf(fid,'%s r=%g betaErr=%g tol=%g inside=%g measuredErr=%g\n', ...
        SF.aperture_mode{i},SF.weak_to_strong_ratio(i), ...
        SF.median_abs_practical_beta_error_over_width(i), ...
        SF.median_allowed_abs_beta_error_over_width_for_E_le_1(i), ...
        SF.fraction_practical_estimates_inside_E_le_1_tolerance(i), ...
        SF.median_measured_practical_error_ratio_correctLS(i));
end

fprintf(fid,'\nDecision\n');
for i=1:height(D)
    fprintf(fid,'%s -> %s | %s\n',D.aperture_mode{i}, ...
        D.pa5_legacy_audit_status{i},D.decision_branch{i});
end
fclose(fid);
end

function make_figures(out,cfg,T,A,C,Ttol,ST,SF)
modes=unique(string(T.aperture_mode),'stable');

f=figure('Visible',cfg.figure_visible);
bar([A.practical_rescue_legacyLS,A.practical_rescue_correctLS,A.oracle_rescue_correctLS]);
xticks(1:height(A)); xticklabels(A.aperture_mode); ylim([0 1]); grid on;
ylabel('Rescue rate on pre-hidden cohort');
title('EXP009 PA5B — Legacy vs Corrected LS Rescue');
legend({'Legacy practical','Corrected practical','Corrected oracle'},'Location','best');
exportgraphics(f,fullfile(out,'fig01_legacy_vs_corrected_rescue.png'),'Resolution',180); close(f);

f=figure('Visible',cfg.figure_visible); hold on; vv=[];
for i=1:numel(modes)
    M=T(string(T.aperture_mode)==modes(i),:);
    scatter(M.predicted_practical_error_ratio,M.measured_practical_error_ratio_correctLS,12,'filled');
    vv=[vv;M.predicted_practical_error_ratio;M.measured_practical_error_ratio_correctLS]; %#ok<AGROW>
end
lo=min(vv); hi=max(vv); plot([lo hi],[lo hi],'--'); grid on;
xlabel('Predicted ||r-w||/||w||'); ylabel('Measured corrected-LS error');
title('EXP009 PA5B — Exact Projection-Error Identity');
legend([cellstr(modes);{'y=x'}],'Location','best');
exportgraphics(f,fullfile(out,'fig02_prediction_vs_measurement.png'),'Resolution',180); close(f);

f=figure('Visible',cfg.figure_visible); hold on;
for i=1:numel(modes)
    M=Ttol(string(Ttol.aperture_mode)==modes(i),:);
    d=unique(M.delta_beta_over_width); med=nan(size(d));
    for j=1:numel(d)
        med(j)=median(M.strong_mismatch_leakage_ratio_to_strong( ...
            abs(M.delta_beta_over_width-d(j))<1e-12),'omitnan');
    end
    plot(d,med,'LineWidth',1.3);
end
grid on; xlabel('\delta\beta_s/W_\beta'); ylabel('||(I-P_h)s||/||s||');
title('EXP009 PA5B — Strong Error to Leakage Transfer');
legend(modes,'Location','best');
exportgraphics(f,fullfile(out,'fig03_strong_mismatch_leakage_transfer.png'),'Resolution',180); close(f);

f=figure('Visible',cfg.figure_visible); hold on;
for rA=cfg.weak_to_strong_ratio
    M=Ttol(string(Ttol.aperture_mode)=="BeamDerived" & Ttol.delta_velocity_mps==10 & ...
        string(Ttol.strong_velocity_side)=="HighV" & abs(Ttol.weak_to_strong_ratio-rA)<1e-12,:);
    [~,o]=sort(M.delta_beta_over_width); M=M(o,:);
    plot(M.delta_beta_over_width,M.predicted_error_ratio,'LineWidth',1.2);
end
yline(1,'--'); grid on; xlabel('\delta\beta_s/W_\beta'); ylabel('Predicted ||r-w||/||w||');
title('EXP009 PA5B — Error Amplification vs Weak/Strong Ratio');
legend([arrayfun(@(x)sprintf('r=%.1f',x),cfg.weak_to_strong_ratio,'UniformOutput',false),{'E=1'}],'Location','best');
exportgraphics(f,fullfile(out,'fig04_error_amplification_vs_beta_error.png'),'Resolution',180); close(f);

f=figure('Visible',cfg.figure_visible); hold on;
for i=1:numel(modes)
    M=ST(string(ST.aperture_mode)==modes(i) & abs(ST.error_threshold-1)<1e-12,:);
    plot(M.weak_to_strong_ratio,M.median_allowed_abs_beta_error_over_width,'o-','LineWidth',1.3);
end
grid on; xlabel('A_w/A_s'); ylabel('Allowed |\delta\beta_s|/W_\beta for E\leq1');
title('EXP009 PA5B — Required Strong-Parameter Accuracy');
legend(modes,'Location','best');
exportgraphics(f,fullfile(out,'fig05_required_beta_accuracy_vs_contrast.png'),'Resolution',180); close(f);

f=figure('Visible',cfg.figure_visible); hold on; xx=[]; yy=[];
for i=1:numel(modes)
    M=SF(string(SF.aperture_mode)==modes(i),:);
    scatter(M.median_allowed_abs_beta_error_over_width_for_E_le_1, ...
        M.median_abs_practical_beta_error_over_width,60,'filled');
    xx=[xx;M.median_allowed_abs_beta_error_over_width_for_E_le_1]; %#ok<AGROW>
    yy=[yy;M.median_abs_practical_beta_error_over_width]; %#ok<AGROW>
end
v=[xx;yy]; v=v(isfinite(v)); lo=min(v); hi=max(v); plot([lo hi],[lo hi],'--');
grid on; xlabel('Allowed |\delta\beta|/W'); ylabel('Observed median |\delta\beta|/W');
title('EXP009 PA5B — Estimator Accuracy vs Subtraction Requirement');
legend([cellstr(modes);{'y=x'}],'Location','best');
exportgraphics(f,fullfile(out,'fig06_estimator_vs_subtraction_tolerance.png'),'Resolution',180); close(f);

f=figure('Visible',cfg.figure_visible);
rr=cfg.weak_to_strong_ratio; Y=nan(numel(rr),2);
for j=1:numel(rr)
    M=T(logical(T.pre_hidden) & abs(T.weak_to_strong_ratio-rr(j))<1e-12,:);
    Y(j,1)=median(M.strong_leak_error_fraction,'omitnan'); Y(j,2)=1-Y(j,1);
end
bar(rr,Y,'stacked'); ylim([0 1]); grid on;
xlabel('A_w/A_s'); ylabel('Fraction of squared recovery error');
title('EXP009 PA5B — Error Ownership');
legend({'Strong mismatch leakage','Weak projection loss'},'Location','best');
exportgraphics(f,fullfile(out,'fig07_error_ownership_vs_contrast.png'),'Resolution',180); close(f);

f=figure('Visible',cfg.figure_visible); hold on;
for i=1:numel(modes)
    M=C(string(C.aperture_mode)==modes(i),:);
    plot(M.weak_to_strong_ratio,M.practical_rescue_correctLS,'o-','LineWidth',1.3);
end
ylim([0 1]); grid on; xlabel('A_w/A_s'); ylabel('Corrected practical rescue');
title('EXP009 PA5B — Corrected Practical Rescue');
legend(modes,'Location','best');
exportgraphics(f,fullfile(out,'fig08_corrected_practical_rescue_vs_contrast.png'),'Resolution',180); close(f);
end
