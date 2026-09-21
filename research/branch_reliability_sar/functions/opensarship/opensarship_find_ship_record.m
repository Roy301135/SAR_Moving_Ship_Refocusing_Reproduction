function ship = opensarship_find_ship_record(xml_path,center_x,center_y)
%OPENSARSHIP_FIND_SHIP_RECORD Find one ship record using filename center x/y.

if ~exist(xml_path,'file')
    error('OpenSARShip:MissingShipXML','Ship.xml not found: %s',xml_path);
end

doc = xmlread(xml_path);
ships = doc.getElementsByTagName('ship');

match = [];
for k = 0:ships.getLength-1
    node = ships.item(k);
    sar = first_child(node,'SARShipInformation');
    if isempty(sar), continue; end
    x = str2double(child_text(sar,'Center_x'));
    y = str2double(child_text(sar,'Center_y'));
    if x == center_x && y == center_y
        if ~isempty(match)
            error('OpenSARShip:NonUniqueShipRecord', ...
                'Multiple Ship.xml records match x=%d y=%d.',center_x,center_y);
        end
        match = node;
    end
end

if isempty(match)
    error('OpenSARShip:ShipRecordNotFound', ...
        'No Ship.xml record matches x=%d y=%d.',center_x,center_y);
end

ship = struct();
ship.SAR = parse_section(first_child(match,'SARShipInformation'));
ship.AIS = parse_section(first_child(match,'AISShipInformation'));
ship.Match = parse_section(first_child(match,'MatchInformation'));
ship.MarineTraffic = parse_section(first_child(match,'MarineTrafficInformation'));

end

function s = parse_section(node)
s = struct();
if isempty(node), return; end
children = node.getChildNodes();
for i=0:children.getLength-1
    c = children.item(i);
    if c.getNodeType ~= c.ELEMENT_NODE, continue; end
    key = matlab.lang.makeValidName(char(c.getNodeName()));
    txt = strtrim(char(c.getTextContent()));
    num = str2double(txt);
    if ~isnan(num) || strcmpi(txt,'NaN')
        s.(key) = num;
    else
        s.(key) = string(txt);
    end
end
end

function node = first_child(parent,name)
node = [];
list = parent.getElementsByTagName(name);
if list.getLength>0
    node = list.item(0);
end
end

function txt = child_text(parent,name)
list = parent.getElementsByTagName(name);
if list.getLength==0
    txt = '';
else
    txt = strtrim(char(list.item(0).getTextContent()));
end
end
