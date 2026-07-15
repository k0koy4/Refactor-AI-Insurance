window.addEventListener('message', function(event) {
  const data = event.data;
  if (data.type === 'dashboard:show') {
    document.getElementById('dashboard').style.display = 'block';
    return;
  }
  if (data.type !== 'dashboard:update') return;

  const activeClaims = document.getElementById('activeClaims');
  const previousClaims = document.getElementById('previousClaims');
  const riskScore = document.getElementById('riskScore');
  const fraudScore = document.getElementById('fraudScore');
  const repairOrders = document.getElementById('repairOrders');
  const progress = document.getElementById('progress');
  const timeline = document.getElementById('timeline');
  const evidence = document.getElementById('evidence');

  function setList(node, items) {
    node.innerHTML = '';
    if (!items || !items.length) {
      const li = document.createElement('li');
      li.textContent = 'None';
      node.appendChild(li);
      return;
    }
    items.forEach(item => {
      const li = document.createElement('li');
      li.textContent = item;
      node.appendChild(li);
    });
  }

  setList(activeClaims, data.activeClaims || []);
  setList(previousClaims, data.previousClaims || []);
  riskScore.textContent = data.riskScore || '0';
  fraudScore.textContent = data.fraudScore || '0';
  setList(repairOrders, data.repairOrders || []);
  setList(progress, data.progress || []);
  setList(timeline, data.timeline || []);
  setList(evidence, data.evidence || []);
});

document.getElementById('close').addEventListener('click', function() {
  fetch(`https://${GetParentResourceName()}/closeDashboard`, { method: 'POST' });
  document.getElementById('dashboard').style.display = 'none';
});
