document.addEventListener('DOMContentLoaded', function() {
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
      TRAIT_MIN_RARITY: parseInt(document.getElementById('trait_min_rarity').value)
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

  function displayOutput(b64, slot) {
    var section = document.querySelector('.output-section');
    var textarea = document.getElementById('output');
    var counter = document.getElementById('size-counter');
    var hint = document.getElementById('usage-hint');

    textarea.value = b64;
    section.classList.add('visible');

    var len = b64.length;
    counter.textContent = len.toLocaleString() + ' / 16,384 chars';
    counter.className = 'size-counter ' + (len > 16384 ? 'over' : len > 14000 ? 'warn' : 'ok');
    hint.textContent = '!bset ' + slot + ' <paste>';
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
