document.addEventListener('DOMContentLoaded', function() {
  // Fetch latest version from GitHub
  fetch('https://api.github.com/repos/bazilio91/beyond-all-random/releases/latest')
    .then(function(r) { return r.json(); })
    .then(function(data) {
      if (data.tag_name) {
        document.getElementById('version-badge').textContent = data.tag_name;
        document.getElementById('changelog-link').href = data.html_url;
      }
    })
    .catch(function() {
      document.getElementById('version-badge').textContent = '';
    });

  // Tab switching
  var tabBtns = document.querySelectorAll('.tab-btn');
  var panels = document.querySelectorAll('.panel');
  tabBtns.forEach(function(btn) {
    btn.addEventListener('click', function() {
      tabBtns.forEach(function(b) { b.classList.remove('active'); });
      panels.forEach(function(p) { p.classList.remove('active'); });
      btn.classList.add('active');
      document.getElementById(btn.dataset.panel).classList.add('active');
      document.querySelector('.output-section').classList.remove('visible');
    });
  });

  // Slider <-> number sync
  document.querySelectorAll('.slider-group').forEach(function(group) {
    var slider = group.querySelector('input[type="range"]');
    var num = group.querySelector('input[type="number"]');
    if (!slider || !num) return;
    slider.addEventListener('input', function() { num.value = slider.value; });
    num.addEventListener('input', function() { slider.value = num.value; });
  });

  // Faction buttons
  var factionBtns = document.querySelectorAll('.faction-btn');
  factionBtns.forEach(function(btn) {
    btn.addEventListener('click', function() {
      factionBtns.forEach(function(b) { b.classList.remove('active'); });
      btn.classList.add('active');
    });
  });

  // Faction multiplier label
  var fSlider = document.getElementById('faction_multiplier');
  var pctLabel = document.getElementById('pct-label');
  if (fSlider) {
    fSlider.addEventListener('input', function() {
      document.getElementById('faction_multiplier_num').value = fSlider.value;
      var pct = Math.round((parseFloat(fSlider.value) - 1) * 100);
      pctLabel.textContent = (pct >= 0 ? '+' : '') + pct + '%';
    });
    document.getElementById('faction_multiplier_num').addEventListener('input', function() {
      fSlider.value = this.value;
      var pct = Math.round((parseFloat(this.value) - 1) * 100);
      pctLabel.textContent = (pct >= 0 ? '+' : '') + pct + '%';
    });
  }

  // Generate rarity mod
  document.getElementById('gen-rarity').addEventListener('click', function() {
    var params = {
      rarity_chance: parseFloat(document.getElementById('rarity_chance').value),
      MIN_FACTORY_RARITY: parseInt(document.getElementById('min_factory_rarity').value),
      CURSE_CHANCE: parseFloat(document.getElementById('curse_chance').value),
      TRAIT_CHANCE: parseFloat(document.getElementById('trait_chance').value),
      TRAIT_MIN_RARITY: parseInt(document.getElementById('trait_min_rarity').value),
      arm_floor: parseInt(document.getElementById('arm_floor').value),
      cor_floor: parseInt(document.getElementById('cor_floor').value),
      leg_floor: parseInt(document.getElementById('leg_floor').value),
      arm_ceil: parseInt(document.getElementById('arm_ceil').value),
      cor_ceil: parseInt(document.getElementById('cor_ceil').value),
      leg_ceil: parseInt(document.getElementById('leg_ceil').value)
    };
    var b64 = RarityTemplate.build(params);
    displayOutput(b64, 'tweakdefs0');
  });

  // Generate faction buff
  document.getElementById('gen-faction').addEventListener('click', function() {
    var active = document.querySelector('.faction-btn.active');
    var faction = active ? active.dataset.faction : 'leg';
    var multiplier = parseFloat(document.getElementById('faction_multiplier').value);
    var b64 = FactionTemplate.build(faction, multiplier);
    displayOutput(b64, 'tweakdefs1');
  });

  // Welcome message
  var welcomeMsg = "!welcome-message Welcome to BEYOND ALL RANDOM!\n" +
    "Every unit gets a random rarity tier — higher rarity = stronger stats but higher cost to build.\n" +
    "High-rarity combat units roll archetypes (Glass Cannon, Tank, Sniper, Brawler) and may get special traits like Phantom (cloaking), Juggernaut (+60% HP), or Plague (sets fires on impact). Some units are cursed — weaker but much cheaper!\n" +
    "To see unit rarities in-game you need the Tweakdefs Bridge widget.\n" +
    "Get it here: https://discord.com/channels/549281623154229250/1468742915315470591\n" +
    "Put the Tweakdefs_bridge.lua file into Beyond-All-Reason/data/LuaUI/Widgets/ (create the Widgets folder if it's missing).\n" +
    "In-game go to Settings → Custom and toggle ON \"Tweakdefs Bridge\".\n" +
    "Press ALT+M to toggle between default and modified unit names. Don't spam it — UI reload takes ~3 sec.\n" +
    "If it doesn't work, restart your game.\n" +
    "Config builder & more info: https://bazilio91.github.io/beyond-all-random/";

  document.getElementById('welcome-preview').textContent = welcomeMsg;

  document.getElementById('gen-welcome').addEventListener('click', function() {
    displayOutput(welcomeMsg, 'welcome');
  });

  function displayOutput(text, slot) {
    var section = document.querySelector('.output-section');
    var textarea = document.getElementById('output');
    var counter = document.getElementById('size-counter');
    var hint = document.getElementById('usage-hint');

    textarea.value = text;
    section.classList.add('visible');

    var len = text.length;
    if (slot === 'welcome') {
      counter.textContent = len + ' chars';
      counter.className = 'size-counter ok';
      hint.textContent = 'Paste into lobby chat';
    } else {
      counter.textContent = len.toLocaleString() + ' / 16,384 chars';
      counter.className = 'size-counter ' + (len > 16384 ? 'over' : len > 14000 ? 'warn' : 'ok');
      hint.textContent = '!bset ' + slot + ' <paste>';
    }
  }

  // Copy to clipboard
  document.getElementById('copy-btn').addEventListener('click', function() {
    var textarea = document.getElementById('output');
    var btn = this;
    navigator.clipboard.writeText(textarea.value).then(function() {
      btn.textContent = 'Copied!';
      btn.classList.add('copied');
      setTimeout(function() {
        btn.textContent = 'Copy to Clipboard';
        btn.classList.remove('copied');
      }, 2000);
    });
  });
});
