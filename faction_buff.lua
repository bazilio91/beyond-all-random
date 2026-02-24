--BaRandom Legion +50% by LoH
--Use with: !bset tweakdefs1 <faction_buff.b64>
local FACTION="leg"
local M=1.5
for name,ud in pairs(UnitDefs) do
	if name:sub(1,#FACTION)==FACTION then
		local MC=ud.metalcost and "metalcost" or "buildcostmetal"
		local EC=ud.energycost and "energycost" or "buildcostenergy"
		local HP=ud.health and "health" or "maxdamage"
		ud[HP]=math.floor(ud[HP]*M)
		if ud.speed then ud.speed=math.floor(ud.speed*M) end
		ud.power=(ud.power or (ud[MC]+(ud[EC]/60)))*M
		if ud.idleautoheal then ud.idleautoheal=ud.idleautoheal*M end
		if ud.weapondefs then
			for _,wd in pairs(ud.weapondefs) do
				if wd.interceptor~=1 and wd.targetable~=1 then
					if wd.range then wd.range=math.floor(wd.range*M) end
					if wd.reloadtime then wd.reloadtime=wd.reloadtime/M end
					if wd.areaofeffect then wd.areaofeffect=math.floor(wd.areaofeffect*M) end
					if wd.damage then
						for k,v in pairs(wd.damage) do
							wd.damage[k]=v*M
						end
					end
				end
			end
		end
		if ud.customparams then
			if ud.customparams.shield_power then ud.customparams.shield_power=math.floor(ud.customparams.shield_power*M) end
			if ud.customparams.shield_radius then ud.customparams.shield_radius=math.floor(ud.customparams.shield_radius*M) end
		end
	end
end
