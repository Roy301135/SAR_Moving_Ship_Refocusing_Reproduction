function scene = opensarship_read_scene_metadata(xml_path)
%OPENSARSHIP_READ_SCENE_METADATA Read selected OpenSARShip scene metadata.

if ~exist(xml_path,'file')
    error('OpenSARShip:MissingSceneXML','Metedata.xml not found: %s',xml_path);
end

doc = xmlread(xml_path);
attrs = doc.getElementsByTagName('attrib');

scene = struct();
wanted = { ...
    'PRODUCT','PRODUCT_TYPE','SPH_DESCRIPTOR','MISSION','ACQUISITION_MODE', ...
    'antenna_pointing','REL_ORBIT','ABS_ORBIT', ...
    'first_line_time','last_line_time', ...
    'range_spacing','azimuth_spacing','pulse_repetition_frequency', ...
    'radar_frequency','line_time_interval', ...
    'num_output_lines','num_samples_per_line', ...
    'subset_offset_x','subset_offset_y','srgr_flag'};

for i=0:attrs.getLength-1
    a = attrs.item(i);
    name = char(a.getAttribute('name'));
    if ~ismember(name,wanted), continue; end
    value = char(a.getAttribute('value'));
    key = matlab.lang.makeValidName(name);
    num = str2double(value);
    if ~isnan(num)
        scene.(key) = num;
    else
        scene.(key) = string(value);
    end
end

% Keep orbit state vectors and Doppler coefficients available for later work
% without requiring the original SAFE annotation.
scene.n_orbit_vectors = doc.getElementsByTagName('orbit_vector1').getLength; %#ok<NASGU>
scene.has_doppler_centroid_coefficients = ...
    doc.getElementsByTagName('Doppler_Centroid_Coefficients').getLength > 0;

end
