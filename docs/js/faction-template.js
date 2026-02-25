const FactionTemplate = {
  factions: {
    arm: { name: "Armada", prefix: "arm" },
    cor: { name: "Cortex", prefix: "cor" },
    leg: { name: "Legion", prefix: "leg" }
  },
  segments: [
    "local a=\"",
    "\"local b=",
    ";for c,d in pairs(UnitDefs)do if c:sub(1,#a)==a then local e=d.metalcost and\"metalcost\"or\"buildcostmetal\"local f=d.energycost and\"energycost\"or\"buildcostenergy\"local g=d.health and\"health\"or\"maxdamage\"d[g]=math.floor(d[g]*b)if d.speed then d.speed=math.floor(d.speed*b)end;d.power=(d.power or d[e]+d[f]/60)*b;if d.idleautoheal then d.idleautoheal=d.idleautoheal*b end;if d.weapondefs then for h,i in pairs(d.weapondefs)do if i.interceptor~=1 and i.targetable~=1 then if i.range then i.range=math.floor(i.range*b)end;if i.reloadtime then i.reloadtime=i.reloadtime/b end;if i.areaofeffect then i.areaofeffect=math.floor(i.areaofeffect*b)end;if i.damage then for j,k in pairs(i.damage)do i.damage[j]=k*b end end end end end;if d.customparams then if d.customparams.shield_power then d.customparams.shield_power=math.floor(d.customparams.shield_power*b)end;if d.customparams.shield_radius then d.customparams.shield_radius=math.floor(d.customparams.shield_radius*b)end end end end"
  ],
  build: function(factionKey, multiplier) {
    var f = this.factions[factionKey];
    var pct = Math.round((multiplier - 1) * 100);
    var sign = pct >= 0 ? "+" : "";
    var header = "--BaRandom " + f.name + " " + sign + pct + "% by LoH";
    var body = this.segments[0] + f.prefix
             + this.segments[1] + multiplier
             + this.segments[2];
    return Pipeline.build(header, body);
  }
};
