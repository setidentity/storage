local chunk={}
local CFRAME_IDS={}
local CFRAME_ROTS={}
do
	local special={
	[0x02]=CFrame.new(),
	[0x03]=CFrame.Angles(math.rad(90),0,0),
	[0x05]=CFrame.Angles(0,math.rad(180),math.rad(180)),
	[0x06]=CFrame.Angles(math.rad(-90),0,0),
	[0x07]=CFrame.Angles(0,math.rad(180),math.rad(90)),
	[0x09]=CFrame.Angles(0,math.rad(90),math.rad(90)),
	[0x0a]=CFrame.Angles(0,0,math.rad(90)),
	[0x0c]=CFrame.Angles(0,math.rad(-90),math.rad(90)),
	[0x0d]=CFrame.Angles(math.rad(-90),math.rad(-90),0),
	[0x0e]=CFrame.Angles(0,math.rad(-90),0),
	[0x10]=CFrame.Angles(math.rad(90),math.rad(-90),0),
	[0x11]=CFrame.Angles(0,math.rad(90),math.rad(180)),
	[0x14]=CFrame.Angles(0,math.rad(180),0),
	[0x15]=CFrame.Angles(math.rad(-90),math.rad(-180),0),
	[0x17]=CFrame.Angles(0,0,math.rad(180)),
	[0x18]=CFrame.Angles(math.rad(90),math.rad(180),0),
	[0x19]=CFrame.Angles(0,0,math.rad(-90)),
	[0x1b]=CFrame.Angles(0,math.rad(-90),math.rad(-90)),
	[0x1c]=CFrame.Angles(0,math.rad(-180),math.rad(-90)),
	[0x1e]=CFrame.Angles(0,math.rad(90),math.rad(-90)),
	[0x1f]=CFrame.Angles(math.rad(90),math.rad(90),0),
	[0x20]=CFrame.Angles(0,math.rad(90),0),
	[0x22]=CFrame.Angles(math.rad(-90),math.rad(90),0),
	[0x23]=CFrame.Angles(0,math.rad(-90),math.rad(180)),
	}
	local function rotkey(cf)
		local c={cf:GetComponents()}
		local parts={}
		for i=4,12 do table.insert(parts,string.format('%d',math.floor(c[i]+0.5))) end
		return table.concat(parts,',')
	end
	for id,cf in pairs(special) do
		CFRAME_IDS[rotkey(cf)]=id
		local c={cf:GetComponents()}
		CFRAME_ROTS[id]={c[4],c[5],c[6],c[7],c[8],c[9],c[10],c[11],c[12]}
	end
end
function chunk.getcframeid(cf)
	local c={cf:GetComponents()}
	local parts={}
	for i=4,12 do table.insert(parts,string.format('%d',math.floor(c[i]+0.5))) end
	return CFRAME_IDS[table.concat(parts,',')]
end
function chunk.decodecframerotations(data,pos,count)
	local rotations={}
	for i=1,count do
		local id,p2=buf.readu8(data,pos) pos=p2
		if id==0 then
			local r={}
			for j=1,9 do local v,p3=buf.readf32le(data,pos) pos=p3 table.insert(r,v) end
			table.insert(rotations,r)
		else
			table.insert(rotations,CFRAME_ROTS[id] or {1,0,0,0,1,0,0,0,1})
		end
	end
	return rotations,pos
end
function chunk.cframexml(name,x,y,z,rot)
	local xml='<CoordinateFrame name="'..buf.xmlescape(name)..'"><X>'..buf.fmt(x)..'</X><Y>'..buf.fmt(y)..'</Y><Z>'..buf.fmt(z)..'</Z>'
	if type(rot)=='table' then
		xml=xml..'<R00>'..buf.fmt(rot[1])..'</R00><R01>'..buf.fmt(rot[2])..'</R01><R02>'..buf.fmt(rot[3])..'</R02>'
		xml=xml..'<R10>'..buf.fmt(rot[4])..'</R10><R11>'..buf.fmt(rot[5])..'</R11><R12>'..buf.fmt(rot[6])..'</R12>'
		xml=xml..'<R20>'..buf.fmt(rot[7])..'</R20><R21>'..buf.fmt(rot[8])..'</R21><R22>'..buf.fmt(rot[9])..'</R22>'
	else
		xml=xml..'<R00>1</R00><R01>0</R01><R02>0</R02><R10>0</R10><R11>1</R11><R12>0</R12><R20>0</R20><R21>0</R21><R22>1</R22>'
	end
	return xml..'</CoordinateFrame>'
end
function chunk.make(tag,data)
	local raw=table.concat(data)
	local compressed=lz4compress(raw)
	local b={}
	buf.writestring(b,tag..string.rep('\0',4-#tag))
	buf.writeu32le(b,#compressed)
	buf.writeu32le(b,#raw)
	buf.writeu32le(b,0)
	buf.writestring(b,compressed)
	return table.concat(b)
end
function chunk.makeraw(tag,data)
	local raw=table.concat(data)
	local b={}
	buf.writestring(b,tag..string.rep('\0',4-#tag))
	buf.writeu32le(b,0)
	buf.writeu32le(b,#raw)
	buf.writeu32le(b,0)
	buf.writestring(b,raw)
	return table.concat(b)
end
function chunk.collectinstances(root)
	local instances={}
	local referents={}
	local id=-1
	local function walk(inst)
		id=id+1
		referents[inst]=id
		table.insert(instances,inst)
		for _,child in ipairs(inst:GetChildren()) do walk(child) end
	end
	walk(root)
	return instances,referents
end
function chunk.groupbyclassname(instances)
	local classgroups={}
	local classorder={}
	local classseen={}
	for _,inst in ipairs(instances) do
		local cn=inst.ClassName
		if not classseen[cn] then
			classseen[cn]=true
			table.insert(classorder,cn)
			classgroups[cn]={typeid=#classorder-1,instances={}}
		end
		table.insert(classgroups[cn].instances,inst)
	end
	return classgroups,classorder
end
function chunk.makeinstchunks(classgroups,classorder,referents)
	local chunks={}
	for _,cn in ipairs(classorder) do
		local group=classgroups[cn]
		local b={}
		buf.writeu32le(b,group.typeid)
		buf.writelenstring(b,cn)
		buf.writeu8(b,0)
		buf.writeu32le(b,#group.instances)
		local refs={}
		for _,inst in ipairs(group.instances) do table.insert(refs,referents[inst]) end
		buf.writestring(b,buf.encodereferents(refs))
		table.insert(chunks,chunk.make('INST',b))
	end
	return chunks
end
function chunk.makeprntchunk(instances,referents)
	local b={}
	buf.writeu8(b,0)
	buf.writeu32le(b,#instances)
	local childrefs,parentrefs={},{}
	for _,inst in ipairs(instances) do
		table.insert(childrefs,referents[inst])
		local par=inst.Parent
		table.insert(parentrefs,(par and referents[par]~=nil) and referents[par] or -1)
	end
	buf.writestring(b,buf.encodereferents(childrefs))
	buf.writestring(b,buf.encodereferents(parentrefs))
	return chunk.make('PRNT',b)
end
return chunk
