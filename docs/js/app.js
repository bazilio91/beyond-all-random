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
      hideAllOutputs();
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

  // Generate rarity mod (both units + buildings)
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
    var unitsB64 = RarityTemplate.build(params);
    var buildingsB64 = BuildingsTemplate.build(params);
    displayDualOutput(unitsB64, buildingsB64);
  });

  // Generate faction buff
  document.getElementById('gen-faction').addEventListener('click', function() {
    var active = document.querySelector('.faction-btn.active');
    var faction = active ? active.dataset.faction : 'leg';
    var multiplier = parseFloat(document.getElementById('faction_multiplier').value);
    var b64 = FactionTemplate.build(faction, multiplier);
    displayOutput(b64, 'tweakdefs2');
  });

  // Welcome message - must be a single line for lobby chat
  var welcomeMsg = "!welcome-message Welcome to BEYOND ALL RANDOM! " +
    "Every unit gets a random rarity tier — higher rarity = stronger stats but higher cost. " +
    "Combat units get archetypes (Glass Cannon, Tank, Sniper, Brawler) and traits like Phantom (cloaking) or Juggernaut (+60% HP). " +
    "Buildings get traits too — Metamorphic mexes auto-evolve to T2! Some units are cursed — weaker but cheaper. " +
    "To see rarities in-game, get the Tweakdefs Bridge widget: https://discord.com/channels/549281623154229250/1468742915315470591/1489715775676616754 " +
    "Config builder: https://bazilio91.github.io/beyond-all-random/";

  document.getElementById('welcome-preview').textContent = welcomeMsg;

  document.getElementById('gen-welcome').addEventListener('click', function() {
    displayOutput(welcomeMsg, 'welcome');
  });

  function hideAllOutputs() {
    document.getElementById('output-section-0').classList.remove('visible');
    document.getElementById('output-section-1').classList.remove('visible');
    document.getElementById('output-section-single').classList.remove('visible');
  }

  function setSizeCounter(el, len) {
    el.textContent = len.toLocaleString() + ' / 16,384 chars';
    el.className = 'size-counter ' + (len > 16384 ? 'over' : len > 14000 ? 'warn' : 'ok');
  }

  function displayDualOutput(unitsText, buildingsText) {
    hideAllOutputs();
    document.getElementById('output-0').value = '!bset tweakdefs ' + unitsText;
    document.getElementById('output-1').value = '!bset tweakdefs1 ' + buildingsText;
    setSizeCounter(document.getElementById('size-counter-0'), unitsText.length);
    setSizeCounter(document.getElementById('size-counter-1'), buildingsText.length);
    document.getElementById('output-section-0').classList.add('visible');
    document.getElementById('output-section-1').classList.add('visible');
  }

  function displayOutput(text, slot) {
    hideAllOutputs();
    var section = document.getElementById('output-section-single');
    var textarea = document.getElementById('output');
    var counter = document.getElementById('size-counter');

    if (slot === 'welcome') {
      textarea.value = text;
      counter.textContent = text.length + ' chars';
      counter.className = 'size-counter ok';
    } else {
      textarea.value = '!bset ' + slot + ' ' + text;
      setSizeCounter(counter, text.length);
    }
    section.classList.add('visible');
  }

  // Copy to clipboard
  document.querySelectorAll('.copy-btn').forEach(function(btn) {
    btn.addEventListener('click', function() {
      var el = document.getElementById(btn.dataset.target);
      navigator.clipboard.writeText(el.value).then(function() {
        btn.textContent = 'Copied!';
        btn.classList.add('copied');
        setTimeout(function() {
          btn.textContent = 'Copy to Clipboard';
          btn.classList.remove('copied');
        }, 2000);
      });
    });
  });
});
