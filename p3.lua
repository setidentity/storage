local types={}
local hadtodothis={
	SoundId=true,MeshId=true,TextureID=true,TextureId=true,
	Texture=true,Image=true,TopImage=true,MidImage=true,BottomImage=true,
	LinkedSource=true,AnimationId=true,VideoId=true,ContentId=true,
}
local ATTR_STRING=0x02
local ATTR_BOOL=0x03
local ATTR_DOUBLE=0x06
local ATTR_UDIM=0x09
local ATTR_UDIM2=0x0A
local ATTR_BRICKCOLOR=0x0E
local ATTR_COLOR3=0x0F
local ATTR_VECTOR2=0x10
local ATTR_VECTOR3=0x11
local ATTR_CFRAME=0x13
local ATTR_NUMBERSEQUENCE=0x17
local ATTR_COLORSEQUENCE=0x19
local ATTR_NUMBERRANGE=0x1B
local ATTR_RECT=0x1C
function types.encodeattributes(inst)
	local ok,attrs=pcall(function() return (inst::any):GetAttributes() end)
	if not ok or not attrs then return '' end
	local keys={}
	for k in pairs(attrs) do table.insert(keys,k) end
	if #keys==0 then return '' end
	table.sort(keys)
	local b={}
	buf.writeu32le(b,#keys)
	for _,k in ipairs(keys) do
		buf.writelenstring(b,k)
		local v=attrs[k]
		local t=typeof(v)
		if t=='string' then
			buf.writeu8(b,ATTR_STRING) buf.writelenstring(b,v)
		elseif t=='boolean' then
			buf.writeu8(b,ATTR_BOOL) buf.writeu8(b,v and 1 or 0)
		elseif t=='number' then
			buf.writeu8(b,ATTR_DOUBLE) buf.writef64le(b,v)
		elseif t=='UDim' then
			buf.writeu8(b,ATTR_UDIM) buf.writef32le(b,v.Scale) buf.writei32le(b,v.Offset)
		elseif t=='UDim2' then
			buf.writeu8(b,ATTR_UDIM2)
			buf.writef32le(b,v.X.Scale) buf.writei32le(b,v.X.Offset)
			buf.writef32le(b,v.Y.Scale) buf.writei32le(b,v.Y.Offset)
		elseif t=='BrickColor' then
			buf.writeu8(b,ATTR_BRICKCOLOR) buf.writeu32le(b,v.Number)
		elseif t=='Color3' then
			buf.writeu8(b,ATTR_COLOR3)
			buf.writef32le(b,v.R) buf.writef32le(b,v.G) buf.writef32le(b,v.B)
		elseif t=='Vector2' then
			buf.writeu8(b,ATTR_VECTOR2) buf.writef32le(b,v.X) buf.writef32le(b,v.Y)
		elseif t=='Vector3' then
			buf.writeu8(b,ATTR_VECTOR3) buf.writef32le(b,v.X) buf.writef32le(b,v.Y) buf.writef32le(b,v.Z)
		elseif t=='CFrame' then
			buf.writeu8(b,ATTR_CFRAME)
			local c={v:GetComponents()}
			for i=1,12 do buf.writef32le(b,c[i]) end
		elseif t=='NumberSequence' then
			buf.writeu8(b,ATTR_NUMBERSEQUENCE)
			buf.writeu32le(b,#v.Keypoints)
			for _,kf in ipairs(v.Keypoints) do
				buf.writef32le(b,kf.Time) buf.writef32le(b,kf.Value) buf.writef32le(b,kf.Envelope)
			end
		elseif t=='ColorSequence' then
			buf.writeu8(b,ATTR_COLORSEQUENCE)
			buf.writeu32le(b,#v.Keypoints)
			for _,kf in ipairs(v.Keypoints) do
				buf.writef32le(b,kf.Time)
				buf.writef32le(b,kf.Value.R) buf.writef32le(b,kf.Value.G) buf.writef32le(b,kf.Value.B)
				buf.writef32le(b,0)
			end
		elseif t=='NumberRange' then
			buf.writeu8(b,ATTR_NUMBERRANGE) buf.writef32le(b,v.Min) buf.writef32le(b,v.Max)
		elseif t=='Rect' then
			buf.writeu8(b,ATTR_RECT)
			buf.writef32le(b,v.Min.X) buf.writef32le(b,v.Min.Y)
			buf.writef32le(b,v.Max.X) buf.writef32le(b,v.Max.Y)
		end
	end
	return table.concat(b)
end
function types.decodeattributesxml(bytes,propname)
	if not bytes or #bytes<4 then return '<BinaryString name="'..buf.xmlescape(propname)..'">'..buf.b64encode(bytes or '')..'</BinaryString>' end
	local pos=1
	local count,p=buf.readu32le(bytes,pos) pos=p
	local attrs={}
	for i=1,count do
		local key,p2=buf.readlenstring(bytes,pos) pos=p2
		local tid,p3=buf.readu8(bytes,pos) pos=p3
		if tid==ATTR_STRING then
			local val,p4=buf.readlenstring(bytes,pos) pos=p4
			table.insert(attrs,'<string key="'..buf.xmlescape(key)..'">'..buf.xmlescape(val)..'</string>')
		elseif tid==ATTR_BOOL then
			local b,pp=buf.readu8(bytes,pos) pos=pp
			table.insert(attrs,'<bool key="'..buf.xmlescape(key)..'">'.. (b~=0 and 'true' or 'false') ..'</bool>')
		elseif tid==ATTR_DOUBLE then
			local v,pp=buf.readf64le(bytes,pos) pos=pp
			table.insert(attrs,'<double key="'..buf.xmlescape(key)..'">'..string.format('%.17g',v)..'</double>')
		elseif tid==ATTR_UDIM then
			local s,pp=buf.readf32le(bytes,pos) local o,pp2=buf.readi32le(bytes,pp) pos=pp2
			table.insert(attrs,'<UDim key="'..buf.xmlescape(key)..'"><S>'..buf.fmt(s)..'</S><O>'..o..'</O></UDim>')
		elseif tid==ATTR_UDIM2 then
			local xs,pp=buf.readf32le(bytes,pos) local xo,pp2=buf.readi32le(bytes,pp)
			local ys,pp3=buf.readf32le(bytes,pp2) local yo,pp4=buf.readi32le(bytes,pp3) pos=pp4
			table.insert(attrs,'<UDim2 key="'..buf.xmlescape(key)..'"><XS>'..buf.fmt(xs)..'</XS><XO>'..xo..'</XO><YS>'..buf.fmt(ys)..'</YS><YO>'..yo..'</YO></UDim2>')
		elseif tid==ATTR_BRICKCOLOR then
			local n,pp=buf.readu32le(bytes,pos) pos=pp
			table.insert(attrs,'<BrickColor key="'..buf.xmlescape(key)..'">'..n..'</BrickColor>')
		elseif tid==ATTR_COLOR3 then
			local r,pp=buf.readf32le(bytes,pos) local g,pp2=buf.readf32le(bytes,pp) local b2,pp3=buf.readf32le(bytes,pp2) pos=pp3
			table.insert(attrs,'<Color3 key="'..buf.xmlescape(key)..'"><R>'..buf.fmt(r)..'</R><G>'..buf.fmt(g)..'</G><B>'..buf.fmt(b2)..'</B></Color3>')
		elseif tid==ATTR_VECTOR2 then
			local x,pp=buf.readf32le(bytes,pos) local y,pp2=buf.readf32le(bytes,pp) pos=pp2
			table.insert(attrs,'<Vector2 key="'..buf.xmlescape(key)..'"><X>'..buf.fmt(x)..'</X><Y>'..buf.fmt(y)..'</Y></Vector2>')
		elseif tid==ATTR_VECTOR3 then
			local x,pp=buf.readf32le(bytes,pos) local y,pp2=buf.readf32le(bytes,pp) local z,pp3=buf.readf32le(bytes,pp2) pos=pp3
			table.insert(attrs,'<Vector3 key="'..buf.xmlescape(key)..'"><X>'..buf.fmt(x)..'</X><Y>'..buf.fmt(y)..'</Y><Z>'..buf.fmt(z)..'</Z></Vector3>')
		elseif tid==ATTR_CFRAME then
			local c={} for j=1,12 do local v,pp=buf.readf32le(bytes,pos) pos=pp c[j]=v end
			table.insert(attrs,'<CFrame key="'..buf.xmlescape(key)..'"><X>'..buf.fmt(c[1])..'</X><Y>'..buf.fmt(c[2])..'</Y><Z>'..buf.fmt(c[3])..'</Z>'
				..'<R00>'..buf.fmt(c[4])..'</R00><R01>'..buf.fmt(c[5])..'</R01><R02>'..buf.fmt(c[6])..'</R02>'
				..'<R10>'..buf.fmt(c[7])..'</R10><R11>'..buf.fmt(c[8])..'</R11><R12>'..buf.fmt(c[9])..'</R12>'
				..'<R20>'..buf.fmt(c[10])..'</R20><R21>'..buf.fmt(c[11])..'</R21><R22>'..buf.fmt(c[12])..'</R22></CFrame>')
		elseif tid==ATTR_NUMBERSEQUENCE then
			local kcount,pp=buf.readu32le(bytes,pos) pos=pp
			local kfs={}
			for k=1,kcount do
				local t,pp2=buf.readf32le(bytes,pos) local v,pp3=buf.readf32le(bytes,pp2) local e,pp4=buf.readf32le(bytes,pp3) pos=pp4
				table.insert(kfs,'<Keypoint><time>'..buf.fmt(t)..'</time><value>'..buf.fmt(v)..'</value><envelope>'..buf.fmt(e)..'</envelope></Keypoint>')
			end
			table.insert(attrs,'<NumberSequence key="'..buf.xmlescape(key)..'">'..table.concat(kfs)..'</NumberSequence>')
		elseif tid==ATTR_COLORSEQUENCE then
			local kcount,pp=buf.readu32le(bytes,pos) pos=pp
			local kfs={}
			for k=1,kcount do
				local t,pp2=buf.readf32le(bytes,pos) local r,pp3=buf.readf32le(bytes,pp2) local g,pp4=buf.readf32le(bytes,pp3) local b2,pp5=buf.readf32le(bytes,pp4) local _,pp6=buf.readf32le(bytes,pp5) pos=pp6
				table.insert(kfs,'<Keypoint><time>'..buf.fmt(t)..'</time><color><R>'..buf.fmt(r)..'</R><G>'..buf.fmt(g)..'</G><B>'..buf.fmt(b2)..'</B></color></Keypoint>')
			end
			table.insert(attrs,'<ColorSequence key="'..buf.xmlescape(key)..'">'..table.concat(kfs)..'</ColorSequence>')
		elseif tid==ATTR_NUMBERRANGE then
			local mn,pp=buf.readf32le(bytes,pos) local mx,pp2=buf.readf32le(bytes,pp) pos=pp2
			table.insert(attrs,'<NumberRange key="'..buf.xmlescape(key)..'">'..buf.fmt(mn)..' '..buf.fmt(mx)..'</NumberRange>')
		elseif tid==ATTR_RECT then
			local x0,pp=buf.readf32le(bytes,pos) local y0,pp2=buf.readf32le(bytes,pp)
			local x1,pp3=buf.readf32le(bytes,pp2) local y1,pp4=buf.readf32le(bytes,pp3) pos=pp4
			table.insert(attrs,'<Rect2D key="'..buf.xmlescape(key)..'"><min><X>'..buf.fmt(x0)..'</X><Y>'..buf.fmt(y0)..'</Y></min><max><X>'..buf.fmt(x1)..'</X><Y>'..buf.fmt(y1)..'</Y></max></Rect2D>')
		else
			break
		end
	end
	return '<Attributes name="'..buf.xmlescape(propname)..'">'..table.concat(attrs)..'</Attributes>'
end
function types.encodepropvalue(vals,typename)
	local t=typeof(vals[1])
	if t=='string' then
		if typename=='Content' then
			return 0x1D,function(b)
			for _,v in ipairs(vals) do buf.writelenstring(b,tostring(v)) end
		end
	end
	return 0x01,function(b) for _,v in ipairs(vals) do buf.writelenstring(b,tostring(v)) end end
elseif t=='boolean' then
	return 0x02,function(b) for _,v in ipairs(vals) do buf.writeu8(b,v and 1 or 0) end end
elseif t=='number' then
	if typename=='int' then
		return 0x03,function(b)
		local ints={}
		for _,v in ipairs(vals) do table.insert(ints,math.floor(v)) end
		buf.writestring(b,buf.interleaveints(ints))
	end
elseif typename=='int64' then
	return 0x1B,function(b)
	local ints={}
	for _,v in ipairs(vals) do table.insert(ints,math.floor(v)) end
	local n=#ints
	local bytes={}
	for i=1,n do
		local v=ints[i]
		local neg=v<0
		if neg then v=-v-1 end
		local bv={}
		for j=1,8 do bv[j]=v%256 v=math.floor(v/256) end
		if neg then for j=1,8 do bv[j]=255-bv[j] end end
		local topbit=math.floor(bv[8]/128)%2
		for j=8,2,-1 do bv[j]=(bv[j]*2)%256+math.floor(bv[j-1]/128) end
		bv[1]=(bv[1]*2)%256+topbit
		for j=1,8 do bytes[(j-1)*n+i]=bv[j] end
	end
	local chars={}
	for _,byte in ipairs(bytes) do table.insert(chars,string.char(byte)) end
	buf.writestring(b,table.concat(chars))
end
elseif typename=='double' then
	return 0x05,function(b)
	for _,v in ipairs(vals) do buf.writef64le(b,v) end
end
else
	return 0x04,function(b)
	local floats={}
	for _,v in ipairs(vals) do table.insert(floats,buf.robloxfloat(v)) end
	buf.writestring(b,buf.interleave(floats))
end
end
elseif t=='UDim' then
	return 0x06,function(b)
	local scales,offsets={},{}
	for _,v in ipairs(vals) do
		table.insert(scales,buf.robloxfloat(v.Scale))
		table.insert(offsets,math.floor(v.Offset))
	end
	buf.writestring(b,buf.interleave(scales))
	buf.writestring(b,buf.interleaveints(offsets))
end
elseif t=='UDim2' then
	return 0x07,function(b)
	local xs,ys,xo,yo={},{},{},{}
	for _,v in ipairs(vals) do
		table.insert(xs,buf.robloxfloat(v.X.Scale))
		table.insert(ys,buf.robloxfloat(v.Y.Scale))
		table.insert(xo,math.floor(v.X.Offset))
		table.insert(yo,math.floor(v.Y.Offset))
	end
	buf.writestring(b,buf.interleave(xs))
	buf.writestring(b,buf.interleave(ys))
	buf.writestring(b,buf.interleaveints(xo))
	buf.writestring(b,buf.interleaveints(yo))
end
elseif t=='Ray' then
	return 0x08,function(b)
	for _,v in ipairs(vals) do
		buf.writef32le(b,v.Origin.X) buf.writef32le(b,v.Origin.Y) buf.writef32le(b,v.Origin.Z)
		buf.writef32le(b,v.Direction.X) buf.writef32le(b,v.Direction.Y) buf.writef32le(b,v.Direction.Z)
	end
end
elseif t=='Faces' then
	return 0x09,function(b)
	for _,v in ipairs(vals) do
		local n=0
		if v.Front then n=n+1 end
		if v.Bottom then n=n+2 end
		if v.Left then n=n+4 end
		if v.Back then n=n+8 end
		if v.Top then n=n+16 end
		if v.Right then n=n+32 end
		buf.writeu8(b,n)
	end
end
elseif t=='Axes' then
	return 0x0A,function(b)
	for _,v in ipairs(vals) do
		local n=0
		if v.X then n=n+1 end
		if v.Y then n=n+2 end
		if v.Z then n=n+4 end
		buf.writeu8(b,n)
	end
end
elseif t=='BrickColor' then
	return 0x0B,function(b)
	local nums={}
	for _,v in ipairs(vals) do table.insert(nums,v.Number) end
	buf.writestring(b,buf.interleave(nums))
end
elseif t=='Color3' then
	if typename=='Color3uint8' then
		return 0x1A,function(b)
		local rs,gs,bs={},{},{}
		for _,v in ipairs(vals) do
			table.insert(rs,math.floor(v.R*255+0.5))
			table.insert(gs,math.floor(v.G*255+0.5))
			table.insert(bs,math.floor(v.B*255+0.5))
		end
		for _,r in ipairs(rs) do buf.writeu8(b,r) end
		for _,g in ipairs(gs) do buf.writeu8(b,g) end
		for _,bv in ipairs(bs) do buf.writeu8(b,bv) end
	end
else
	return 0x0C,function(b)
	local rs,gs,bs={},{},{}
	for _,v in ipairs(vals) do
		table.insert(rs,buf.robloxfloat(v.R))
		table.insert(gs,buf.robloxfloat(v.G))
		table.insert(bs,buf.robloxfloat(v.B))
	end
	buf.writestring(b,buf.interleave(rs))
	buf.writestring(b,buf.interleave(gs))
	buf.writestring(b,buf.interleave(bs))
end
end
elseif t=='Vector2' then
	return 0x0D,function(b)
	local xs,ys={},{}
	for _,v in ipairs(vals) do table.insert(xs,buf.robloxfloat(v.X)) table.insert(ys,buf.robloxfloat(v.Y)) end
	buf.writestring(b,buf.interleave(xs)) buf.writestring(b,buf.interleave(ys))
end
elseif t=='Vector3' then
	return 0x0E,function(b)
	local xs,ys,zs={},{},{}
	for _,v in ipairs(vals) do
		table.insert(xs,buf.robloxfloat(v.X))
		table.insert(ys,buf.robloxfloat(v.Y))
		table.insert(zs,buf.robloxfloat(v.Z))
	end
	buf.writestring(b,buf.interleave(xs)) buf.writestring(b,buf.interleave(ys)) buf.writestring(b,buf.interleave(zs))
end
elseif t=='CFrame' then
	return 0x10,function(b)
	local xs,ys,zs={},{},{}
	for _,v in ipairs(vals) do
		local id=chunk.getcframeid(v)
		if id then
			buf.writeu8(b,id)
		else
			local c={v:GetComponents()}
			buf.writeu8(b,0)
			for i=4,12 do buf.writef32le(b,c[i]) end
		end
		table.insert(xs,buf.robloxfloat(v.X))
		table.insert(ys,buf.robloxfloat(v.Y))
		table.insert(zs,buf.robloxfloat(v.Z))
	end
	buf.writestring(b,buf.interleave(xs)) buf.writestring(b,buf.interleave(ys)) buf.writestring(b,buf.interleave(zs))
end
elseif t=='EnumItem' then
	return 0x12,function(b)
	local nums={}
	for _,v in ipairs(vals) do table.insert(nums,v.Value) end
	buf.writestring(b,buf.interleave(nums))
end
elseif t=='Instance' then
	return 0x13,function(b)
	local refs={}
	for _ in ipairs(vals) do table.insert(refs,-1) end
	buf.writestring(b,buf.encodereferents(refs))
end
elseif t=='Vector3int16' then
	return 0x14,function(b)
	for _,v in ipairs(vals) do
		local function wi16(n)
			n=math.floor(n)
			if n<0 then n=n+65536 end
			table.insert(b,string.char(n%256,math.floor(n/256)%256))
		end
		wi16(v.X) wi16(v.Y) wi16(v.Z)
	end
end
elseif t=='NumberSequence' then
	return 0x15,function(b)
	for _,v in ipairs(vals) do
		buf.writeu32le(b,#v.Keypoints)
		for _,kf in ipairs(v.Keypoints) do buf.writef32le(b,kf.Time) buf.writef32le(b,kf.Value) buf.writef32le(b,kf.Envelope) end
	end
end
elseif t=='ColorSequence' then
	return 0x16,function(b)
	for _,v in ipairs(vals) do
		buf.writeu32le(b,#v.Keypoints)
		for _,kf in ipairs(v.Keypoints) do
			buf.writef32le(b,kf.Time)
			buf.writef32le(b,kf.Value.R) buf.writef32le(b,kf.Value.G) buf.writef32le(b,kf.Value.B)
			buf.writef32le(b,0)
		end
	end
end
elseif t=='NumberRange' then
	return 0x17,function(b) for _,v in ipairs(vals) do buf.writef32le(b,v.Min) buf.writef32le(b,v.Max) end end
elseif t=='Rect' then
	return 0x18,function(b)
	local x0s,y0s,x1s,y1s={},{},{},{}
	for _,v in ipairs(vals) do
		table.insert(x0s,buf.robloxfloat(v.Min.X)) table.insert(y0s,buf.robloxfloat(v.Min.Y))
		table.insert(x1s,buf.robloxfloat(v.Max.X)) table.insert(y1s,buf.robloxfloat(v.Max.Y))
	end
	buf.writestring(b,buf.interleave(x0s)) buf.writestring(b,buf.interleave(y0s))
	buf.writestring(b,buf.interleave(x1s)) buf.writestring(b,buf.interleave(y1s))
end
elseif t=='PhysicalProperties' then
	return 0x19,function(b) for _ in ipairs(vals) do buf.writeu8(b,1) end end
else
	return nil,nil
end
end
function types.decodepropvalues(typeid,data,pos,count,propname,sstr,classname)
	if typeid==0x01 then
		local pt=classname and types.getproptype and types.getproptype(classname,propname) or nil
		local iscontent=pt=='Content' or hadtodothis[propname]
		local vals={}
		for i=1,count do
			local s,p=buf.readlenstring(data,pos) pos=p
			if iscontent then
				if s=='' then
					table.insert(vals,'<Content name="'..buf.xmlescape(propname)..'" null="true" />')
				else
					table.insert(vals,'<Content name="'..buf.xmlescape(propname)..'"><url>'..buf.xmlescape(s)..'</url></Content>')
				end
			else
				table.insert(vals,'<string name="'..buf.xmlescape(propname)..'">'..buf.xmlescape(s)..'</string>')
			end
		end
		return vals,pos
	elseif typeid==0x02 then
		local vals={}
		for i=1,count do
			local b,p=buf.readu8(data,pos) pos=p
			table.insert(vals,'<bool name="'..buf.xmlescape(propname)..'">'.. (b~=0 and 'true' or 'false') ..'</bool>')
		end
		return vals,pos
	elseif typeid==0x03 then
		local ints,p=buf.deinterleaveints(data,pos,count) pos=p
		local vals={}
		for _,v in ipairs(ints) do table.insert(vals,'<int name="'..buf.xmlescape(propname)..'">'..math.floor(v)..'</int>') end
		return vals,pos
	elseif typeid==0x04 then
		local floats,p=buf.deinterleaverobfloats(data,pos,count) pos=p
		local vals={}
		for _,v in ipairs(floats) do table.insert(vals,'<float name="'..buf.xmlescape(propname)..'">'..buf.fmt(v)..'</float>') end
		return vals,pos
	elseif typeid==0x05 then
		local vals={}
		for i=1,count do
			local v,p=buf.readf64le(data,pos) pos=p
			table.insert(vals,'<double name="'..buf.xmlescape(propname)..'">'..string.format('%.17g',v)..'</double>')
		end
		return vals,pos
	elseif typeid==0x06 then
		local scales,p=buf.deinterleaverobfloats(data,pos,count)
		local offsets,p2=buf.deinterleaveints(data,p,count) pos=p2
		local vals={}
		for i=1,count do table.insert(vals,'<UDim name="'..buf.xmlescape(propname)..'"><S>'..buf.fmt(scales[i])..'</S><O>'..math.floor(offsets[i])..'</O></UDim>') end
		return vals,pos
	elseif typeid==0x07 then
		local xs,p=buf.deinterleaverobfloats(data,pos,count)
		local ys,p2=buf.deinterleaverobfloats(data,p,count)
		local xo,p3=buf.deinterleaveints(data,p2,count)
		local yo,p4=buf.deinterleaveints(data,p3,count) pos=p4
		local vals={}
		for i=1,count do table.insert(vals,'<UDim2 name="'..buf.xmlescape(propname)..'"><XS>'..buf.fmt(xs[i])..'</XS><XO>'..math.floor(xo[i])..'</XO><YS>'..buf.fmt(ys[i])..'</YS><YO>'..math.floor(yo[i])..'</YO></UDim2>') end
		return vals,pos
	elseif typeid==0x08 then
		local vals={}
		for i=1,count do
			local ox,p1=buf.readf32le(data,pos) local oy,p2=buf.readf32le(data,p1) local oz,p3=buf.readf32le(data,p2)
			local dx,p4=buf.readf32le(data,p3) local dy,p5=buf.readf32le(data,p4) local dz,p6=buf.readf32le(data,p5) pos=p6
			table.insert(vals,'<Ray name="'..buf.xmlescape(propname)..'"><origin><X>'..buf.fmt(ox)..'</X><Y>'..buf.fmt(oy)..'</Y><Z>'..buf.fmt(oz)..'</Z></origin><direction><X>'..buf.fmt(dx)..'</X><Y>'..buf.fmt(dy)..'</Y><Z>'..buf.fmt(dz)..'</Z></direction></Ray>')
		end
		return vals,pos
	elseif typeid==0x09 then
		local vals={}
		for i=1,count do
			local b,p=buf.readu8(data,pos) pos=p
			local front=(math.floor(b/1)%2==1) and 'true' or 'false'
			local bottom=(math.floor(b/2)%2==1) and 'true' or 'false'
			local left=(math.floor(b/4)%2==1) and 'true' or 'false'
			local back=(math.floor(b/8)%2==1) and 'true' or 'false'
			local top=(math.floor(b/16)%2==1) and 'true' or 'false'
			local right=(math.floor(b/32)%2==1) and 'true' or 'false'
			table.insert(vals,'<Faces name="'..buf.xmlescape(propname)..'"><front>'..front..'</front><bottom>'..bottom..'</bottom><left>'..left..'</left><back>'..back..'</back><top>'..top..'</top><right>'..right..'</right></Faces>')
		end
		return vals,pos
	elseif typeid==0x0A then
		local vals={}
		for i=1,count do
			local b,p=buf.readu8(data,pos) pos=p
			local x=(b%2==1) and 'true' or 'false'
			local y=(math.floor(b/2)%2==1) and 'true' or 'false'
			local z=(math.floor(b/4)%2==1) and 'true' or 'false'
			table.insert(vals,'<Axes name="'..buf.xmlescape(propname)..'"><X>'..x..'</X><Y>'..y..'</Y><Z>'..z..'</Z></Axes>')
		end
		return vals,pos
	elseif typeid==0x0B then
		local nums,p=buf.deinterleave(data,pos,count) pos=p
		local vals={}
		for _,v in ipairs(nums) do table.insert(vals,'<BrickColor name="'..buf.xmlescape(propname)..'">'..v..'</BrickColor>') end
		return vals,pos
	elseif typeid==0x0C then
		local rs,p=buf.deinterleaverobfloats(data,pos,count)
		local gs,p2=buf.deinterleaverobfloats(data,p,count)
		local bs,p3=buf.deinterleaverobfloats(data,p2,count) pos=p3
		local vals={}
		for i=1,count do table.insert(vals,'<Color3 name="'..buf.xmlescape(propname)..'"><R>'..buf.fmt(rs[i])..'</R><G>'..buf.fmt(gs[i])..'</G><B>'..buf.fmt(bs[i])..'</B></Color3>') end
		return vals,pos
	elseif typeid==0x0D then
		local xs,p=buf.deinterleaverobfloats(data,pos,count)
		local ys,p2=buf.deinterleaverobfloats(data,p,count) pos=p2
		local vals={}
		for i=1,count do table.insert(vals,'<Vector2 name="'..buf.xmlescape(propname)..'"><X>'..buf.fmt(xs[i])..'</X><Y>'..buf.fmt(ys[i])..'</Y></Vector2>') end
		return vals,pos
	elseif typeid==0x0E then
		local xs,p=buf.deinterleaverobfloats(data,pos,count)
		local ys,p2=buf.deinterleaverobfloats(data,p,count)
		local zs,p3=buf.deinterleaverobfloats(data,p2,count) pos=p3
		local vals={}
		for i=1,count do table.insert(vals,'<Vector3 name="'..buf.xmlescape(propname)..'"><X>'..buf.fmt(xs[i])..'</X><Y>'..buf.fmt(ys[i])..'</Y><Z>'..buf.fmt(zs[i])..'</Z></Vector3>') end
		return vals,pos
	elseif typeid==0x10 then
		local rotations,p=chunk.decodecframerotations(data,pos,count)
		local xs,p2=buf.deinterleaverobfloats(data,p,count)
		local ys,p3=buf.deinterleaverobfloats(data,p2,count)
		local zs,p4=buf.deinterleaverobfloats(data,p3,count) pos=p4
		local vals={}
		for i=1,count do table.insert(vals,chunk.cframexml(propname,xs[i],ys[i],zs[i],rotations[i])) end
		return vals,pos
	elseif typeid==0x12 then
		local nums,p=buf.deinterleave(data,pos,count) pos=p
		local vals={}
		for _,v in ipairs(nums) do table.insert(vals,'<token name="'..buf.xmlescape(propname)..'">'..v..'</token>') end
		return vals,pos
	elseif typeid==0x13 then
		local refs,p=buf.decodereferents(data,pos,count) pos=p
		local vals={}
		for _,v in ipairs(refs) do table.insert(vals,'<Ref name="'..buf.xmlescape(propname)..'">'.. (v==-1 and 'null' or tostring(v)) ..'</Ref>') end
		return vals,pos
	elseif typeid==0x14 then
		local vals={}
		for i=1,count do
			local x=string.byte(data,pos)+string.byte(data,pos+1)*256
			local y=string.byte(data,pos+2)+string.byte(data,pos+3)*256
			local z=string.byte(data,pos+4)+string.byte(data,pos+5)*256
			pos=pos+6
			if x>=32768 then x=x-65536 end
			if y>=32768 then y=y-65536 end
			if z>=32768 then z=z-65536 end
			table.insert(vals,'<Vector3int16 name="'..buf.xmlescape(propname)..'"><X>'..x..'</X><Y>'..y..'</Y><Z>'..z..'</Z></Vector3int16>')
		end
		return vals,pos
	elseif typeid==0x15 then
		local vals={}
		for i=1,count do
			local kcount,p2=buf.readu32le(data,pos) pos=p2
			local kfs={}
			for k=1,kcount do
				local t,p3=buf.readf32le(data,pos) local v,p4=buf.readf32le(data,p3) local e,p5=buf.readf32le(data,p4) pos=p5
				table.insert(kfs,'<Keypoint><time>'..buf.fmt(t)..'</time><value>'..buf.fmt(v)..'</value><envelope>'..buf.fmt(e)..'</envelope></Keypoint>')
			end
			table.insert(vals,'<NumberSequence name="'..buf.xmlescape(propname)..'">'..table.concat(kfs)..'</NumberSequence>')
		end
		return vals,pos
	elseif typeid==0x16 then
		local vals={}
		for i=1,count do
			local kcount,p2=buf.readu32le(data,pos) pos=p2
			local kfs={}
			for k=1,kcount do
				local t,p3=buf.readf32le(data,pos) local r,p4=buf.readf32le(data,p3) local g,p5=buf.readf32le(data,p4) local b2,p6=buf.readf32le(data,p5) local _,p7=buf.readf32le(data,p6) pos=p7
				table.insert(kfs,'<Keypoint><time>'..buf.fmt(t)..'</time><color><R>'..buf.fmt(r)..'</R><G>'..buf.fmt(g)..'</G><B>'..buf.fmt(b2)..'</B></color></Keypoint>')
			end
			table.insert(vals,'<ColorSequence name="'..buf.xmlescape(propname)..'">'..table.concat(kfs)..'</ColorSequence>')
		end
		return vals,pos
	elseif typeid==0x17 then
		local vals={}
		for i=1,count do
			local mn,p1=buf.readf32le(data,pos) local mx,p2=buf.readf32le(data,p1) pos=p2
			table.insert(vals,'<NumberRange name="'..buf.xmlescape(propname)..'">'..buf.fmt(mn)..' '..buf.fmt(mx)..'</NumberRange>')
		end
		return vals,pos
	elseif typeid==0x18 then
		local x0s,p=buf.deinterleaverobfloats(data,pos,count)
		local y0s,p2=buf.deinterleaverobfloats(data,p,count)
		local x1s,p3=buf.deinterleaverobfloats(data,p2,count)
		local y1s,p4=buf.deinterleaverobfloats(data,p3,count) pos=p4
		local vals={}
		for i=1,count do table.insert(vals,'<Rect2D name="'..buf.xmlescape(propname)..'"><min><X>'..buf.fmt(x0s[i])..'</X><Y>'..buf.fmt(y0s[i])..'</Y></min><max><X>'..buf.fmt(x1s[i])..'</X><Y>'..buf.fmt(y1s[i])..'</Y></max></Rect2D>') end
		return vals,pos
	elseif typeid==0x19 then
		local vals={}
		for i=1,count do
			local custom,p1=buf.readu8(data,pos) pos=p1
			if custom==1 then
				local d,p2=buf.readf32le(data,pos) local f,p3=buf.readf32le(data,p2) local e,p4=buf.readf32le(data,p3)
				local fw,p5=buf.readf32le(data,p4) local ew,p6=buf.readf32le(data,p5) pos=p6
				table.insert(vals,'<PhysicalProperties name="'..buf.xmlescape(propname)..'"><CustomPhysics>true</CustomPhysics><Density>'..buf.fmt(d)..'</Density><Friction>'..buf.fmt(f)..'</Friction><Elasticity>'..buf.fmt(e)..'</Elasticity><FrictionWeight>'..buf.fmt(fw)..'</FrictionWeight><ElasticityWeight>'..buf.fmt(ew)..'</ElasticityWeight></PhysicalProperties>')
			else
				table.insert(vals,'<PhysicalProperties name="'..buf.xmlescape(propname)..'"><CustomPhysics>false</CustomPhysics></PhysicalProperties>')
			end
		end
		return vals,pos
	elseif typeid==0x1A then
		local rs={string.byte(data,pos,pos+count-1)}
		local gs={string.byte(data,pos+count,pos+count*2-1)}
		local bs={string.byte(data,pos+count*2,pos+count*3-1)}
		pos=pos+count*3
		local vals={}
		for i=1,count do table.insert(vals,'<Color3uint8 name="'..buf.xmlescape(propname)..'"><R>'..rs[i]..'</R><G>'..gs[i]..'</G><B>'..bs[i]..'</B></Color3uint8>') end
		return vals,pos
	elseif typeid==0x1B then
		local n=count
		local bs={string.byte(data,pos,pos+n*8-1)}
		local vals={}
		for i=1,n do
			local bv={}
			for j=1,8 do bv[j]=bs[(j-1)*n+i] end
			local botbit=bv[1]%2
			for j=1,7 do bv[j]=math.floor(bv[j]/2)+math.floor(bv[j+1]/128)*128 end
			bv[8]=math.floor(bv[8]/2)+botbit*128
			local neg=(bv[1]%2==1)
			if neg then for j=1,8 do bv[j]=255-bv[j] end end
			local v=0
			for j=8,1,-1 do v=v*256+bv[j] end
			if neg then v=-(v+1) end
			table.insert(vals,'<int64 name="'..buf.xmlescape(propname)..'">'..string.format('%d',v)..'</int64>')
		end
		return vals,pos+n*8
	elseif typeid==0x1C then
		local vals={}
		for i=1,count do
			local len,p=buf.readu32le(data,pos) pos=p
			local bytes=data:sub(pos,pos+len-1) pos=pos+len
			if propname=='AttributesSerialize' or propname=='Attributes' then
				table.insert(vals,types.decodeattributesxml(bytes,propname))
			else
				table.insert(vals,'<BinaryString name="'..buf.xmlescape(propname)..'">'..buf.b64encode(bytes)..'</BinaryString>')
			end
		end
		return vals,pos
	elseif typeid==0x1D then
		local vals={}
		for i=1,count do
			local s,p=buf.readlenstring(data,pos) pos=p
			if s=='' then
				table.insert(vals,'<Content name="'..buf.xmlescape(propname)..'" null="true" />')
			else
				table.insert(vals,'<Content name="'..buf.xmlescape(propname)..'"><url>'..buf.xmlescape(s)..'</url></Content>')
			end
		end
		return vals,pos
	elseif typeid==0x1E then
		local rotations,p=chunk.decodecframerotations(data,pos,count)
		local xs,p2=buf.deinterleaverobfloats(data,p,count)
		local ys,p3=buf.deinterleaverobfloats(data,p2,count)
		local zs,p4=buf.deinterleaverobfloats(data,p3,count)
		local presencestart=p4
		local vals={}
		for i=1,count do
			local present=string.byte(data,presencestart+i-1)
			if present==0x00 then
				table.insert(vals,'<OptionalCoordinateFrame name="'..buf.xmlescape(propname)..'" null="true" />')
			else
				local xml='<OptionalCoordinateFrame name="'..buf.xmlescape(propname)..'"><CFrame><X>'..buf.fmt(xs[i])..'</X><Y>'..buf.fmt(ys[i])..'</Y><Z>'..buf.fmt(zs[i])..'</Z>'
				local rot=rotations[i]
				if type(rot)=='table' then
					xml=xml..'<R00>'..buf.fmt(rot[1])..'</R00><R01>'..buf.fmt(rot[2])..'</R01><R02>'..buf.fmt(rot[3])..'</R02>'
					xml=xml..'<R10>'..buf.fmt(rot[4])..'</R10><R11>'..buf.fmt(rot[5])..'</R11><R12>'..buf.fmt(rot[6])..'</R12>'
					xml=xml..'<R20>'..buf.fmt(rot[7])..'</R20><R21>'..buf.fmt(rot[8])..'</R21><R22>'..buf.fmt(rot[9])..'</R22>'
				else
					xml=xml..'<R00>1</R00><R01>0</R01><R02>0</R02><R10>0</R10><R11>1</R11><R12>0</R12><R20>0</R20><R21>0</R21><R22>1</R22>'
				end
				table.insert(vals,xml..'</CFrame></OptionalCoordinateFrame>')
			end
		end
		return vals,presencestart+count
	elseif typeid==0x1F then
		local vals={}
		for i=1,count do
			local idx,p=buf.readu32le(data,pos) pos=p
			local s=sstr and sstr[idx] or ''
			if s=='' then
				table.insert(vals,'<SharedString name="'..buf.xmlescape(propname)..'" null="true" />')
			else
				table.insert(vals,'<SharedString name="'..buf.xmlescape(propname)..'">'..buf.b64encode(s)..'</SharedString>')
			end
		end
		return vals,pos
	elseif typeid==0x20 then
		local vals={}
		for i=1,count do
			local flen,p=buf.readu32le(data,pos) pos=p
			local family=data:sub(pos,pos+flen-1) pos=pos+flen
			local weight=string.byte(data,pos)+string.byte(data,pos+1)*256 pos=pos+2
			local style=string.byte(data,pos) pos=pos+1
			local clen,p2=buf.readu32le(data,pos) pos=p2
			local cacheid=data:sub(pos,pos+clen-1) pos=pos+clen
			table.insert(vals,'<Font name="'..buf.xmlescape(propname)..'"><Family><uri>'..buf.xmlescape(family)..'</uri></Family><Weight>'..weight..'</Weight><Style>'..style..'</Style><CachedFaceId>'..buf.xmlescape(cacheid)..'</CachedFaceId></Font>')
		end
		return vals,pos
	elseif typeid==0x21 then
		local n=count
		local bs={string.byte(data,pos,pos+n*8-1)}
		local vals={}
		for i=1,n do
			local hi=bs[i]*16777216+bs[i+n]*65536+bs[i+n*2]*256+bs[i+n*3]
			local lo=bs[i+n*4]*16777216+bs[i+n*5]*65536+bs[i+n*6]*256+bs[i+n*7]
			local v=hi*4294967296+lo
			table.insert(vals,'<SecurityCapabilities name="'..buf.xmlescape(propname)..'">'..string.format('%d',v)..'</SecurityCapabilities>')
		end
		return vals,pos+n*8
	else
		return nil,pos
	end
end
return types
