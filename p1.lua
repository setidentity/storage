local buf={}
function buf.writeu8(b,v) table.insert(b,string.char(math.floor(v)%256)) end
function buf.writeu16le(b,v) v=math.floor(v)%65536 table.insert(b,string.char(v%256,math.floor(v/256)%256)) end
function buf.writeu32le(b,v)
	v=math.floor(v)%4294967296
	table.insert(b,string.char(v%256,math.floor(v/256)%256,math.floor(v/65536)%256,math.floor(v/16777216)%256))
end
function buf.writei32le(b,v) if v<0 then v=v+4294967296 end buf.writeu32le(b,v) end
function buf.writef32le(b,v)
	if v~=v then buf.writeu32le(b,0) return end
	if v==0 then buf.writeu32le(b,0) return end
	local sign=0
	if v<0 then sign=1 v=-v end
	if v==math.huge then buf.writeu32le(b,sign*2^31+255*2^23) return end
	local exp=math.floor(math.log(v)/math.log(2))
	local mantissa=v/2^exp-1
	if mantissa<0 then mantissa=0 end
	if mantissa>=1 then mantissa=1-1/2^23 end
	exp=exp+127
	if exp<=0 then exp=0 elseif exp>=255 then exp=255 end
	buf.writeu32le(b,math.floor(sign*2^31+exp*2^23+math.floor(mantissa*2^23+0.5))%4294967296)
end
function buf.writef64le(b,v)
	if v~=v then for i=1,8 do buf.writeu8(b,0) end return end
	if v==0 then for i=1,8 do buf.writeu8(b,0) end return end
	local sign=0
	if v<0 then sign=1 v=-v end
	if v==math.huge then
		for i=1,6 do buf.writeu8(b,0) end buf.writeu8(b,0xF0) buf.writeu8(b,sign==1 and 0xFF or 0x7F) return
	end
	local exp=math.floor(math.log(v)/math.log(2))
	local mantissa=v/2^exp-1
	if mantissa<0 then mantissa=0 end
	if mantissa>=1 then mantissa=1-1/2^52 end
	exp=exp+1023
	if exp<=0 then exp=0 elseif exp>=2047 then exp=2047 end
	local mhi=math.floor(mantissa*2^20)%1048576
	local mlo=math.floor((mantissa*2^20-mhi)*2^32)%4294967296
	local hi=sign*2147483648+exp*1048576+mhi
	buf.writeu32le(b,math.floor(mlo)%4294967296)
	buf.writeu32le(b,math.floor(hi)%4294967296)
end
function buf.writei64le(b,v)
	local neg=v<0
	if neg then v=-v-1 end
	local lo=v%4294967296
	local hi=math.floor(v/4294967296)%4294967296
	if neg then lo=4294967295-lo hi=4294967295-hi end
	buf.writeu32le(b,lo) buf.writeu32le(b,hi)
end
function buf.writestring(b,s) table.insert(b,s) end
function buf.writelenstring(b,s) buf.writeu32le(b,#s) table.insert(b,s) end
function buf.readu8(data,pos) return string.byte(data,pos),pos+1 end
function buf.readu16le(data,pos)
	local a,b=string.byte(data,pos,pos+1)
	return a+b*256,pos+2
end
function buf.readu32le(data,pos)
	local a,b,c,d=string.byte(data,pos,pos+3)
	return a+b*256+c*65536+d*16777216,pos+4
end
function buf.readi32le(data,pos)
	local v,p=buf.readu32le(data,pos)
	if v>=2147483648 then v=v-4294967296 end
	return v,p
end
function buf.readf32le(data,pos)
	local bits,p=buf.readu32le(data,pos)
	if bits==0 then return 0,p end
	local sign=math.floor(bits/2^31)
	local exp=math.floor(bits/2^23)%256
	local mantissa=bits%2^23
	if exp==0 then return 0,p end
	if exp==255 then return(sign==1 and -math.huge or math.huge),p end
	local v=(1+mantissa/2^23)*2^(exp-127)
	if sign==1 then v=-v end
	return v,p
end
function buf.readf64le(data,pos)
	local lo,p1=buf.readu32le(data,pos)
	local hi,p2=buf.readu32le(data,p1)
	if hi==0 and lo==0 then return 0,p2 end
	local sign=math.floor(hi/2147483648)%2
	local exp=math.floor(hi/1048576)%2048
	local mhi=hi%1048576
	if exp==0 then return 0,p2 end
	if exp==2047 then return(sign==1 and -math.huge or math.huge),p2 end
	local mantissa=mhi/1048576+lo/4503599627370496
	local v=(1+mantissa)*2^(exp-1023)
	if sign==1 then v=-v end
	return v,p2
end
function buf.readi64le(data,pos)
	local lo,p1=buf.readu32le(data,pos)
	local hi,p2=buf.readu32le(data,p1)
	if hi>=2147483648 then
		lo=4294967295-lo
		hi=4294967295-hi
		return -(lo+hi*4294967296+1),p2
	end
	return lo+hi*4294967296,p2
end
function buf.readlenstring(data,pos)
	local len,p=buf.readu32le(data,pos)
	return data:sub(p,p+len-1),p+len
end
function buf.robloxfloat(v)
	if v~=v then return 0 end
	if v==0 then return 0 end
	local sign=0
	if v<0 then sign=1 v=-v end
	if v==math.huge then
		local bits=(sign*2^31+255*2^23)%4294967296
		local r=(bits*2)%4294967296
		if bits>=2147483648 then r=r+1 end
		return math.floor(r)
	end
	local exp=math.floor(math.log(v)/math.log(2))
	local mantissa=v/2^exp-1
	if mantissa<0 then mantissa=0 end
	if mantissa>=1 then mantissa=1-1/2^23 end
	exp=exp+127
	if exp<=0 then exp=0 elseif exp>=255 then exp=255 end
	local bits=(sign*2^31+exp*2^23+math.floor(mantissa*2^23+0.5))%4294967296
	local r=(bits*2)%4294967296
	if bits>=2147483648 then r=r+1 end
	return math.floor(r)
end
function buf.unrobloxfloat(bits)
	local rotated=math.floor(bits%4294967296)
	local unrotated=math.floor(rotated/2)
	if rotated%2==1 then unrotated=unrotated+2147483648 end
	unrotated=unrotated%4294967296
	if unrotated==0 then return 0 end
	local sign=math.floor(unrotated/2^31)
	local exp=math.floor(unrotated/2^23)%256
	local mantissa=unrotated%2^23
	if exp==0 then return 0 end
	local v=(1+mantissa/2^23)*2^(exp-127)
	if sign==1 then v=-v end
	return v
end
function buf.zigzag(v)
	v=math.floor(v)
	if v>=0 then return v*2 else return(-v)*2-1 end
end
function buf.unzigzag(v)
	if v%2==0 then return v/2 else return-(v+1)/2 end
end
function buf.interleave(ints)
	local n=#ints
	local b={}
	for i=1,n do
		local v=math.floor(ints[i])%4294967296
		b[i]=math.floor(v/16777216)%256
		b[i+n]=math.floor(v/65536)%256
		b[i+n*2]=math.floor(v/256)%256
		b[i+n*3]=v%256
	end
	local chars={}
	for _,byte in ipairs(b) do table.insert(chars,string.char(byte)) end
	return table.concat(chars)
end
function buf.interleaveints(ints)
	local zz={}
	for _,v in ipairs(ints) do table.insert(zz,buf.zigzag(v)) end
	return buf.interleave(zz)
end
function buf.deinterleave(data,pos,count)
	local n=count
	local bytes={string.byte(data,pos,pos+n*4-1)}
	local result={}
	for i=1,n do
		result[i]=bytes[i]*16777216+bytes[i+n]*65536+bytes[i+n*2]*256+bytes[i+n*3]
	end
	return result,pos+n*4
end
function buf.deinterleaveints(data,pos,count)
	local raw,p=buf.deinterleave(data,pos,count)
	local result={}
	for _,v in ipairs(raw) do
		if v%2==0 then table.insert(result,v/2)
		else table.insert(result,-(v+1)/2) end
	end
	return result,p
end
function buf.deinterleaverobfloats(data,pos,count)
	local raw,p=buf.deinterleave(data,pos,count)
	local result={}
	for _,v in ipairs(raw) do table.insert(result,buf.unrobloxfloat(v)) end
	return result,p
end
function buf.encodereferents(refs)
	local deltas={}
	local prev=0
	for _,r in ipairs(refs) do
		table.insert(deltas,r-prev)
		prev=r
	end
	return buf.interleaveints(deltas)
end
function buf.decodereferents(data,pos,count)
	local deltas,p=buf.deinterleaveints(data,pos,count)
	local result={}
	local acc=0
	for _,d in ipairs(deltas) do acc=acc+d table.insert(result,acc) end
	return result,p
end
function buf.xmlescape(s)
	s=tostring(s)
	s=s:gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;'):gsub('"','&quot;')
	return s
end
function buf.fmt(n)
	if n==math.huge then return 'INF'
	elseif n==-math.huge then return '-INF'
	elseif n~=n then return 'NAN' end
	return string.format('%.9g',n)
end
function buf.b64encode(bytes)
	local chars='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
	local out={}
	for i=1,#bytes,3 do
		local a,b,c=string.byte(bytes,i),string.byte(bytes,i+1) or 0,string.byte(bytes,i+2) or 0
		local n=a*65536+b*256+c
		table.insert(out,chars:sub(math.floor(n/262144)%64+1,math.floor(n/262144)%64+1))
		table.insert(out,chars:sub(math.floor(n/4096)%64+1,math.floor(n/4096)%64+1))
		table.insert(out,i+1<=#bytes and chars:sub(math.floor(n/64)%64+1,math.floor(n/64)%64+1) or '=')
		table.insert(out,i+2<=#bytes and chars:sub(n%64+1,n%64+1) or '=')
	end
	return table.concat(out)
end
return buf
