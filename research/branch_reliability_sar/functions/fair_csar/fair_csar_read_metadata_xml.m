function meta = fair_csar_read_metadata_xml(xml_path)
%FAIR_CSAR_READ_METADATA_XML Read the simple FAIR-CSAR metadata XML.
%
% Uses fileread + regexp only, avoiding Java/XML toolbox dependencies.

txt = fileread(xml_path);

meta = struct();

meta.azimuth_size = get_num(txt,'azimuth');
meta.range_size = get_num(txt,'range');

meta.azimuth_start = get_num(txt,'azimuthStart');
meta.range_start = get_num(txt,'rangeStart');
meta.azimuth_end = get_num(txt,'azimuthEnd');
meta.range_end = get_num(txt,'rangeEnd');

meta.imaging_mode = get_str(txt,'imgingMode');
meta.nominal_resolution = get_num(txt,'nominalResolution');
meta.polarization_mode = get_str(txt,'polarizationMode');
meta.velocity_mps = get_num(txt,'velocity');
meta.radar_center_frequency_hz = get_num(txt,'radarCenterFrequency');
meta.prf_hz = get_num(txt,'prf');
meta.look_direction = get_str(txt,'lookDirection');

meta.patch_width = get_num(txt,'width');
meta.patch_height = get_num(txt,'height');

% Candidate B has one object. For robustness use the first polygon found.
meta.major_category = get_str(txt,'majorCategory');
meta.sub_category = get_str(txt,'subCategory');
meta.incidence_angle_deg = get_num(txt,'incidenceAngle');
meta.attitude_angle_deg = get_num(txt,'attitudeAngle');

meta.x = [get_num(txt,'x1'), get_num(txt,'x2'), ...
          get_num(txt,'x3'), get_num(txt,'x4')];
meta.y = [get_num(txt,'y1'), get_num(txt,'y2'), ...
          get_num(txt,'y3'), get_num(txt,'y4')];

end

function v = get_num(txt, tag)
pat = ['<' tag '>\s*([-+0-9.eE]+)\s*</' tag '>'];
tok = regexp(txt,pat,'tokens','once');
if isempty(tok)
    error('Missing numeric XML tag: <%s>',tag);
end
v = str2double(tok{1});
end

function s = get_str(txt, tag)
pat = ['<' tag '>\s*([^<]+?)\s*</' tag '>'];
tok = regexp(txt,pat,'tokens','once');
if isempty(tok)
    error('Missing string XML tag: <%s>',tag);
end
s = strtrim(tok{1});
end
