/**
 * Hierarchy Atlas - Interactive Application Logic
 * Comprehensive Kenya Administrative Geography & Hierarchical SQL Explorer
 */

// KNBS 47 Counties Data (Official Codes and Names)
const COUNTIES = [
  { code: '01', name: 'Mombasa' },
  { code: '02', name: 'Kwale' },
  { code: '03', name: 'Kilifi' },
  { code: '04', name: 'Tana River' },
  { code: '05', name: 'Lamu' },
  { code: '06', name: 'Taita-Taveta' },
  { code: '07', name: 'Garissa' },
  { code: '08', name: 'Wajir' },
  { code: '09', name: 'Mandera' },
  { code: '10', name: 'Marsabit' },
  { code: '11', name: 'Isiolo' },
  { code: '12', name: 'Meru' },
  { code: '13', name: 'Tharaka-Nithi' },
  { code: '14', name: 'Embu' },
  { code: '15', name: 'Kitui' },
  { code: '16', name: 'Machakos' },
  { code: '17', name: 'Makueni' },
  { code: '18', name: 'Nyandarua' },
  { code: '19', name: 'Nyeri' },
  { code: '20', name: 'Kirinyaga' },
  { code: '21', name: "Murang'a" },
  { code: '22', name: 'Kiambu' },
  { code: '23', name: 'Turkana' },
  { code: '24', name: 'West Pokot' },
  { code: '25', name: 'Samburu' },
  { code: '26', name: 'Trans Nzoia' },
  { code: '27', name: 'Uasin Gishu' },
  { code: '28', name: 'Elgeyo-Marakwet' },
  { code: '29', name: 'Nandi' },
  { code: '30', name: 'Baringo' },
  { code: '31', name: 'Laikipia' },
  { code: '32', name: 'Nakuru' },
  { code: '33', name: 'Narok' },
  { code: '34', name: 'Kajiado' },
  { code: '35', name: 'Kericho' },
  { code: '36', name: 'Bomet' },
  { code: '37', name: 'Kakamega' },
  { code: '38', name: 'Vihiga' },
  { code: '39', name: 'Bungoma' },
  { code: '40', name: 'Busia' },
  { code: '41', name: 'Siaya' },
  { code: '42', name: 'Kisumu' },
  { code: '43', name: 'Homa Bay' },
  { code: '44', name: 'Migori' },
  { code: '45', name: 'Kisii' },
  { code: '46', name: 'Nyamira' },
  { code: '47', name: 'Nairobi' }
];

// Benchmark Metrics Dataset (Empirical pgbench on PostgreSQL 16)
const BENCHMARK_METRICS = {
  subtree_read: {
    title: 'Subtree Read Performance (Fetching 131 Nairobi nodes)',
    unit: 'TPS',
    desc: 'Throughput (Transactions Per Second) under 10 concurrent clients (Higher is better)',
    subMetricTitle: 'Average Query Latency',
    data: [
      { model: 'Adjacency List', tps: 2532.63, latency: '3.95 ms', val: 2532.63, maxVal: 4500, class: 'fill-adj', note: 'Recursive CTE joins across 5 levels' },
      { model: 'Nested Sets', tps: 3672.41, latency: '2.72 ms', val: 3672.41, maxVal: 4500, class: 'fill-nested', note: 'O(1) range scan between lft and rgt' },
      { model: 'Closure Table', tps: 2654.32, latency: '3.77 ms', val: 2654.32, maxVal: 4500, class: 'fill-closure', note: 'Single join on region_closure ancestor_id' },
      { model: 'ltree (GiST)', tps: 4387.90, latency: '2.28 ms', val: 4387.90, maxVal: 4500, class: 'fill-ltree', isWinner: true, note: 'GiST index subtree containment operator <@' }
    ]
  },
  ancestor_lookup: {
    title: 'Ancestor Path Lookup (Traversing from Leaf Village to Root)',
    unit: 'TPS',
    desc: 'Throughput climbing the hierarchy chain to Kenya (Higher is better)',
    subMetricTitle: 'Average Query Latency',
    data: [
      { model: 'Adjacency List', tps: 4684.64, latency: '2.14 ms', val: 4684.64, maxVal: 7500, class: 'fill-adj', note: 'Ascending recursive CTE on parent_id' },
      { model: 'Nested Sets', tps: 4096.61, latency: '2.44 ms', val: 4096.61, maxVal: 7500, class: 'fill-nested', note: 'ancestor.lft <= node.lft AND ancestor.rgt >= node.rgt' },
      { model: 'Closure Table', tps: 4211.45, latency: '2.37 ms', val: 4211.45, maxVal: 7500, class: 'fill-closure', note: 'descendant_id lookup ordered by depth DESC' },
      { model: 'ltree (Path @>)', tps: 7278.00, latency: '1.37 ms', val: 7278.00, maxVal: 7500, class: 'fill-ltree', isWinner: true, note: 'Path containment operator @> parses string path' }
    ]
  },
  move_subtree: {
    title: 'Move Subtree Write Performance (Reparenting Sub-hierarchy)',
    unit: 'TPS',
    desc: 'Throughput modifying tree structure and maintaining consistency (Higher is better)',
    subMetricTitle: 'Write Transaction Latency',
    data: [
      { model: 'Adjacency List', tps: 684.86, latency: '7.30 ms', val: 684.86, maxVal: 700, class: 'fill-adj', isWinner: true, note: 'Single-row O(1) UPDATE on parent_id' },
      { model: 'Closure Table', tps: 249.80, latency: '20.02 ms', val: 249.80, maxVal: 700, class: 'fill-closure', note: 'Delete obsolete ancestor links + Cartesian join insert' },
      { model: 'ltree', tps: 20.74, latency: '230.80 ms', val: 20.74, maxVal: 700, class: 'fill-ltree', note: 'Cascading subpath() update on all descendant rows' },
      { model: 'Nested Sets', tps: 1.22, latency: '4,107.65 ms', val: 1.22, maxVal: 700, class: 'fill-nested', isAlert: true, note: 'Global table lock: shifts bounds across all 6,158 rows' }
    ]
  },
  storage_overhead: {
    title: 'Storage Footprint & Index Overhead (6,158 Nodes)',
    unit: 'kB',
    desc: 'Total storage consumed beyond base Adjacency List table (Lower is better)',
    subMetricTitle: 'Relative Size Overhead',
    data: [
      { model: 'Adjacency List', tps: 0, latency: '0% (Baseline)', val: 50, maxVal: 3800, class: 'fill-adj', isWinner: true, note: 'Minimal storage: only 1 integer parent_id column' },
      { model: 'Nested Sets', tps: 384, latency: '+6% overhead', val: 384, maxVal: 3800, class: 'fill-nested', note: '+2 integer columns (lft, rgt) and composite index' },
      { model: 'ltree', tps: 1152, latency: '+19% overhead', val: 1152, maxVal: 3800, class: 'fill-ltree', note: 'Path string column + GiST index + B-Tree index' },
      { model: 'Closure Table', tps: 3624, latency: '+60% overhead', val: 3624, maxVal: 3800, class: 'fill-closure', isAlert: true, note: '29,000 transitive rows in region_closure table' }
    ]
  }
};

// Simulation Scenarios
const SIM_SCENARIOS = {
  read_subtree: {
    title: 'Read Subtree (Nairobi & 130 Descendants)',
    models: {
      adj: {
        title: 'Adjacency List',
        sql: `WITH RECURSIVE subtree AS (\n  SELECT id, name, level, code, parent_id, 0 AS depth\n  FROM regions WHERE name = 'Nairobi'\n  UNION ALL\n  SELECT c.id, c.name, c.level, c.code, c.parent_id, s.depth + 1\n  FROM regions c JOIN subtree s ON c.parent_id = s.id\n)\nSELECT * FROM subtree;`,
        metrics: '2,532.63 TPS · 3.95 ms · 317 buffer hits'
      },
      nested: {
        title: 'Nested Sets',
        sql: `SELECT c.id, c.name, c.level, c.code, c.parent_id, c.lft, c.rgt\nFROM regions root\nJOIN regions c ON c.lft BETWEEN root.lft AND root.rgt\nWHERE root.name = 'Nairobi'\nORDER BY c.lft;`,
        metrics: '3,672.41 TPS · 2.72 ms · 25 buffer hits'
      },
      closure: {
        title: 'Closure Table',
        sql: `SELECT r.id, r.name, r.level, r.code, r.parent_id, c.depth\nFROM region_closure c\nJOIN regions r ON r.id = c.descendant_id\nWHERE c.ancestor_id = (SELECT id FROM regions WHERE name = 'Nairobi' LIMIT 1)\nORDER BY c.depth;`,
        metrics: '2,654.32 TPS · 3.77 ms · 424 buffer hits'
      },
      ltree: {
        title: 'PostgreSQL ltree',
        sql: `SELECT id, name, level, code, parent_id, path\nFROM regions\nWHERE path <@ 'Kenya.Nairobi';`,
        metrics: '4,387.90 TPS (Champion) · 2.28 ms · 109 buffer hits'
      }
    }
  },
  ancestor_path: {
    title: 'Climb Ancestor Chain (Village -> Kenya Root)',
    models: {
      adj: {
        title: 'Adjacency List',
        sql: `WITH RECURSIVE ancestors AS (\n  SELECT id, name, level, parent_id, 0 AS depth\n  FROM regions WHERE name = 'Nairobi Village 1.1.1'\n  UNION ALL\n  SELECT p.id, p.name, p.level, p.parent_id, a.depth + 1\n  FROM regions p JOIN ancestors a ON p.id = a.parent_id\n)\nSELECT * FROM ancestors ORDER BY depth DESC;`,
        metrics: '4,684.64 TPS · 2.14 ms · 4 joins'
      },
      nested: {
        title: 'Nested Sets',
        sql: `SELECT a.id, a.name, a.level, a.code, a.lft, a.rgt\nFROM regions node\nJOIN regions a ON node.lft BETWEEN a.lft AND a.rgt\nWHERE node.name = 'Nairobi Village 1.1.1'\nORDER BY a.lft ASC;`,
        metrics: '4,096.61 TPS · 2.44 ms · index range'
      },
      closure: {
        title: 'Closure Table',
        sql: `SELECT r.id, r.name, r.level, c.depth\nFROM region_closure c\nJOIN regions r ON r.id = c.ancestor_id\nWHERE c.descendant_id = (SELECT id FROM regions WHERE name = 'Nairobi Village 1.1.1' LIMIT 1)\nORDER BY c.depth DESC;`,
        metrics: '4,211.45 TPS · 2.37 ms · 5 rows matched'
      },
      ltree: {
        title: 'PostgreSQL ltree',
        sql: `SELECT id, name, level, path\nFROM regions\nWHERE path @> 'Kenya.Nairobi.Sub_1.Ward_1.Village_1'\nORDER BY path ASC;`,
        metrics: '7,278.00 TPS (Champion) · 1.37 ms · GiST path parse'
      }
    }
  },
  move_subtree: {
    title: 'Subtree Reparenting (Move Sub-County to another County)',
    models: {
      adj: {
        title: 'Adjacency List',
        sql: `-- O(1) single-row atomic pointer update\nUPDATE regions\nSET parent_id = :new_county_id\nWHERE id = :sub_county_id;`,
        metrics: '684.86 TPS (Champion) · 7.30 ms · 1 row affected'
      },
      nested: {
        title: 'Nested Sets',
        sql: `-- 4-Step Global Interval Shift:\n-- 1. Invert bounds: UPDATE regions SET lft = -lft, rgt = -rgt WHERE lft BETWEEN sub_lft AND sub_rgt;\n-- 2. Close gap: UPDATE regions SET lft = lft - width WHERE lft > sub_rgt; ...\n-- 3. Open destination gap: UPDATE regions SET lft = lft + width ...\n-- 4. Restore subtree: UPDATE regions SET lft = -lft + offset ...`,
        metrics: '1.22 TPS (Severe Anomaly) · 4,107 ms · 6,158 rows locked'
      },
      closure: {
        title: 'Closure Table',
        sql: `-- Step 1: Disconnect old ancestors\nDELETE FROM region_closure WHERE descendant_id IN (SELECT descendant_id FROM region_closure WHERE ancestor_id = :sub_id) AND ancestor_id NOT IN (SELECT descendant_id FROM region_closure WHERE ancestor_id = :sub_id);\n-- Step 2: Cartesian join insert new ancestor links\nINSERT INTO region_closure (ancestor_id, descendant_id, depth) ...;`,
        metrics: '249.80 TPS · 20.02 ms · hundreds of link rows inserted'
      },
      ltree: {
        title: 'PostgreSQL ltree',
        sql: `-- Cascading path replacement on subtree descendants\nUPDATE regions\nSET path = :new_parent_path || subpath(path, nlevel(:old_sub_path) - 1)\nWHERE path <@ :old_sub_path;`,
        metrics: '20.74 TPS · 230.80 ms · 26 descendant rows updated'
      }
    }
  }
};

// Current Selected Tree State
let currentCountyCode = '47'; // Default Nairobi (Official KNBS code 47)
let selectedNodeData = null;

// Initialize on DOM Loaded
document.addEventListener('DOMContentLoaded', () => {
  initCountyDropdown();
  renderTree(currentCountyCode);
  initBenchmarkTabs();
  initSimulator();
  initLightbox();
  initClipboardButtons();
});

// 1. Populate County Dropdown
function initCountyDropdown() {
  const dropdown = document.getElementById('county-select');
  if (!dropdown) return;

  dropdown.innerHTML = '';
  COUNTIES.forEach(c => {
    const opt = document.createElement('option');
    opt.value = c.code;
    opt.textContent = `${c.code} - ${c.name}`;
    if (c.code === currentCountyCode) opt.selected = true;
    dropdown.appendChild(opt);
  });

  dropdown.addEventListener('change', (e) => {
    currentCountyCode = e.target.value;
    renderTree(currentCountyCode);
  });
}

// 2. Deterministic Node Calculation for Selected County
function getCountyHierarchy(countyCode) {
  const county = COUNTIES.find(c => c.code === countyCode) || COUNTIES[46]; // Default Nairobi (code 47)
  const countyIdx = parseInt(county.code, 10);
  
  // Base IDs and bounds for deterministic demonstration
  // In the real DB: Root Kenya is 1. 47 Counties are 2..48.
  const countyId = countyIdx + 1;
  const countyLft = 2 + (countyIdx - 1) * 262;
  const countyRgt = countyLft + 261;
  const countyPath = `Kenya.${county.name.replace(/[^A-Za-z0-9_]/g, '')}`;

  const tree = {
    id: countyId,
    name: county.name,
    level: 'County',
    code: county.code,
    parentId: 1, // Kenya
    lft: countyLft,
    rgt: countyRgt,
    path: countyPath,
    subCountiesCount: 5,
    wardsCount: 25,
    villagesCount: 100,
    totalNodes: 131,
    children: []
  };

  for (let s = 1; s <= 5; s++) {
    const subLft = countyLft + 1 + (s - 1) * 52;
    const subRgt = subLft + 51;
    const subId = 1000 + countyIdx * 10 + s;
    const subPath = `${countyPath}.Sub_${s}`;

    const subCounty = {
      id: subId,
      name: `${county.name} Sub-${s}`,
      level: 'Sub-County',
      code: `${county.code}-${s}`,
      parentId: countyId,
      lft: subLft,
      rgt: subRgt,
      path: subPath,
      totalNodes: 26,
      children: []
    };

    for (let w = 1; w <= 5; w++) {
      const wardLft = subLft + 1 + (w - 1) * 10;
      const wardRgt = wardLft + 9;
      const wardId = 3000 + subId * 5 + w;
      const wardPath = `${subPath}.Ward_${w}`;

      const ward = {
        id: wardId,
        name: `${county.name} Ward ${s}.${w}`,
        level: 'Ward',
        code: `${county.code}-${s}-${w}`,
        parentId: subId,
        lft: wardLft,
        rgt: wardRgt,
        path: wardPath,
        totalNodes: 5,
        children: []
      };

      for (let v = 1; v <= 4; v++) {
        const villageLft = wardLft + 1 + (v - 1) * 2;
        const villageRgt = villageLft + 1;
        const villageId = 10000 + wardId * 4 + v;
        const villagePath = `${wardPath}.Village_${v}`;

        ward.children.push({
          id: villageId,
          name: `${county.name} Village ${s}.${w}.${v}`,
          level: 'Village',
          code: null,
          parentId: wardId,
          lft: villageLft,
          rgt: villageRgt,
          path: villagePath,
          totalNodes: 1,
          children: []
        });
      }
      subCounty.children.push(ward);
    }
    tree.children.push(subCounty);
  }

  return tree;
}

// 3. Render Tree in UI
function renderTree(countyCode) {
  const container = document.getElementById('tree-view-container');
  if (!container) return;

  const countyData = getCountyHierarchy(countyCode);
  container.innerHTML = '';

  // Render Root Kenya Wrapper
  const rootWrap = document.createElement('div');
  rootWrap.className = 'tree-node-item';

  const rootRow = document.createElement('div');
  rootRow.className = 'node-row';
  rootRow.innerHTML = `
    <button class="node-toggle-btn expanded" id="kenya-toggle">▶</button>
    <span class="node-level-tag level-country">Country</span>
    <span class="node-name">Kenya</span>
    <span class="node-code">Code: KE</span>
  `;

  rootRow.addEventListener('click', (e) => {
    if (e.target.classList.contains('node-toggle-btn')) {
      toggleNode(e.target);
      return;
    }
    selectNode({
      id: 1,
      name: 'Kenya',
      level: 'Country',
      code: 'KE',
      parentId: 'NULL (Root Node)',
      lft: 1,
      rgt: 12316,
      path: 'Kenya',
      totalNodes: 6158
    }, rootRow);
  });

  const kenyaChildren = document.createElement('div');
  kenyaChildren.className = 'node-children';

  // Render the County Node
  const countyNodeEl = createTreeNodeElement(countyData, true);
  kenyaChildren.appendChild(countyNodeEl);

  rootWrap.appendChild(rootRow);
  rootWrap.appendChild(kenyaChildren);
  container.appendChild(rootWrap);

  // Auto-select County Node initially
  const countyRow = countyNodeEl.querySelector('.node-row');
  selectNode(countyData, countyRow);
}

function createTreeNodeElement(node, isAutoExpanded = false) {
  const item = document.createElement('div');
  item.className = 'tree-node-item';

  const hasChildren = node.children && node.children.length > 0;
  const levelClass = `level-${node.level.toLowerCase().replace(/\s+/g, '-')}`;

  const row = document.createElement('div');
  row.className = 'node-row';
  row.innerHTML = `
    ${hasChildren ? `<button class="node-toggle-btn ${isAutoExpanded ? 'expanded' : ''}">▶</button>` : '<span style="width:18px;"></span>'}
    <span class="node-level-tag ${levelClass}">${node.level}</span>
    <span class="node-name">${node.name}</span>
    ${node.code ? `<span class="node-code">${node.code}</span>` : ''}
  `;

  let childrenContainer = null;
  if (hasChildren) {
    childrenContainer = document.createElement('div');
    childrenContainer.className = 'node-children';
    if (!isAutoExpanded) {
      childrenContainer.style.display = 'none';
    }

    // Build children
    node.children.forEach(child => {
      // Auto-expand first sub-county for visual depth
      const childAutoExpand = (node.level === 'County' && child.name.endsWith('Sub-1'));
      childrenContainer.appendChild(createTreeNodeElement(child, childAutoExpand));
    });
  }

  row.addEventListener('click', (e) => {
    if (e.target.classList.contains('node-toggle-btn')) {
      toggleNode(e.target);
      return;
    }
    selectNode(node, row);
  });

  item.appendChild(row);
  if (childrenContainer) {
    item.appendChild(childrenContainer);
  }

  return item;
}

function toggleNode(btn) {
  const row = btn.closest('.node-row');
  const parentItem = row.parentElement;
  const childrenContainer = parentItem.querySelector('.node-children');
  if (!childrenContainer) return;

  const isExpanded = btn.classList.contains('expanded');
  if (isExpanded) {
    btn.classList.remove('expanded');
    childrenContainer.style.display = 'none';
  } else {
    btn.classList.add('expanded');
    childrenContainer.style.display = 'block';
  }
}

// 4. Node Inspector Panel
function selectNode(node, element) {
  selectedNodeData = node;

  // Highlight active row
  document.querySelectorAll('.node-row').forEach(r => r.classList.remove('active'));
  if (element) element.classList.add('active');

  const titleEl = document.getElementById('inspect-title');
  const breadcrumbEl = document.getElementById('inspect-breadcrumb');
  const adjProp = document.getElementById('prop-adj');
  const nestedProp = document.getElementById('prop-nested');
  const closureProp = document.getElementById('prop-closure');
  const ltreeProp = document.getElementById('prop-ltree');
  const sqlPreview = document.getElementById('inspect-sql-preview');

  if (titleEl) titleEl.textContent = `${node.name} (${node.level})`;
  if (breadcrumbEl) breadcrumbEl.textContent = `Path: ${node.path}`;

  // Adjacency List details
  if (adjProp) {
    adjProp.innerHTML = `
      <strong>ID:</strong> ${node.id}<br>
      <strong>Parent ID:</strong> ${node.parentId}<br>
      <strong>Level:</strong> ${node.level}
    `;
  }

  // Nested Sets details
  if (nestedProp) {
    const subtreeCount = Math.floor((node.rgt - node.lft + 1) / 2);
    nestedProp.innerHTML = `
      <strong>lft:</strong> ${node.lft.toLocaleString()} · <strong>rgt:</strong> ${node.rgt.toLocaleString()}<br>
      <strong>Span:</strong> ${node.rgt - node.lft + 1} bounds<br>
      <strong>Subtree Size:</strong> ${subtreeCount.toLocaleString()} nodes
    `;
  }

  // Closure Table details
  if (closureProp) {
    closureProp.innerHTML = `
      <strong>Descendants:</strong> ${node.totalNodes || 1} transitive paths<br>
      <strong>Self-Depth:</strong> 0 (reflexive)<br>
      <strong>Storage Key:</strong> (ancestor_id, descendant_id)
    `;
  }

  // ltree details
  if (ltreeProp) {
    const depth = node.path.split('.').length;
    ltreeProp.innerHTML = `
      <strong>Path:</strong> ${node.path}<br>
      <strong>nlevel(path):</strong> ${depth} labels<br>
      <strong>GiST Index:</strong> idx_regions_path_gist
    `;
  }

  // SQL Query Preview for this specific node
  if (sqlPreview) {
    sqlPreview.textContent = `-- Fetch subtree of "${node.name}" in ltree:
SELECT id, name, level, path 
FROM regions 
WHERE path <@ '${node.path}';

-- Or in Nested Sets:
SELECT * FROM regions 
WHERE lft BETWEEN ${node.lft} AND ${node.rgt};`;
  }
}

// 5. Benchmark Visualizer Tabs
function initBenchmarkTabs() {
  const tabs = document.querySelectorAll('.bench-tab-btn');
  const container = document.getElementById('chart-bars-wrap');
  const titleEl = document.getElementById('bench-chart-title');
  const descEl = document.getElementById('bench-chart-desc');

  if (!tabs || tabs.length === 0) return;

  function renderBenchmark(metricKey) {
    const metric = BENCHMARK_METRICS[metricKey];
    if (!metric || !container) return;

    if (titleEl) titleEl.textContent = metric.title;
    if (descEl) descEl.textContent = metric.desc;

    container.innerHTML = '';

    metric.data.forEach(item => {
      const row = document.createElement('div');
      row.className = 'chart-bar-row';

      const pct = Math.max(5, (item.val / item.maxVal) * 100);

      row.innerHTML = `
        <div class="chart-model-label">
          <span>${item.model}</span>
          ${item.isWinner ? '<span class="win-badge">CHAMPION</span>' : ''}
          ${item.isAlert ? '<span class="alert-badge">ANOMALY</span>' : ''}
        </div>
        <div class="chart-track">
          <div class="chart-fill ${item.class}" style="width: 0%;" data-target-width="${pct}%">
            ${item.val.toLocaleString()} ${metric.unit}
          </div>
        </div>
        <div class="chart-val-col">
          ${item.val.toLocaleString()} ${metric.unit}
          <span class="chart-sub-metric">${item.latency}</span>
        </div>
      `;

      container.appendChild(row);
    });

    // Trigger animation
    setTimeout(() => {
      const fills = container.querySelectorAll('.chart-fill');
      fills.forEach(f => {
        f.style.width = f.getAttribute('data-target-width');
      });
    }, 50);
  }

  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      tabs.forEach(t => t.classList.remove('active'));
      tab.classList.add('active');
      const metricKey = tab.getAttribute('data-metric');
      renderBenchmark(metricKey);
    });
  });

  // Render default tab
  renderBenchmark('subtree_read');
}

// 6. Interactive Simulator
function initSimulator() {
  const buttons = document.querySelectorAll('.sim-btn');
  if (!buttons || buttons.length === 0) return;

  function renderScenario(scenarioKey) {
    const sc = SIM_SCENARIOS[scenarioKey];
    if (!sc) return;

    const displayGrid = document.getElementById('sim-grid-wrap');
    if (!displayGrid) return;

    displayGrid.innerHTML = '';

    Object.entries(sc.models).forEach(([key, modelData]) => {
      const panel = document.createElement('div');
      panel.className = 'sim-panel';

      panel.innerHTML = `
        <div class="sim-panel-title">
          <span>${modelData.title}</span>
        </div>
        <div class="sim-code-block">${escapeHtml(modelData.sql)}</div>
        <div class="sim-metrics-tag">
          <span>Observed Metrics:</span>
          <strong>${modelData.metrics}</strong>
        </div>
      `;
      displayGrid.appendChild(panel);
    });
  }

  buttons.forEach(btn => {
    btn.addEventListener('click', () => {
      buttons.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const scKey = btn.getAttribute('data-scenario');
      renderScenario(scKey);
    });
  });

  renderScenario('read_subtree');
}

// 7. Lightbox Modal for DBeaver Schema
function initLightbox() {
  const frame = document.getElementById('erd-image-trigger');
  const modal = document.getElementById('lightbox-modal');
  const closeBtn = document.getElementById('lightbox-close');

  if (!frame || !modal) return;

  frame.addEventListener('click', () => {
    modal.classList.add('active');
    document.body.style.overflow = 'hidden';
  });

  const closeModal = () => {
    modal.classList.remove('active');
    document.body.style.overflow = '';
  };

  if (closeBtn) closeBtn.addEventListener('click', closeModal);

  modal.addEventListener('click', (e) => {
    if (e.target === modal) closeModal();
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && modal.classList.contains('active')) {
      closeModal();
    }
  });
}

// 8. Clipboard Buttons with Toast
function initClipboardButtons() {
  const buttons = document.querySelectorAll('.code-copy-btn, .btn-copy');
  const toast = document.getElementById('toast-notice');

  buttons.forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const codeTarget = btn.getAttribute('data-copy-target');
      let textToCopy = '';

      if (codeTarget) {
        const el = document.querySelector(codeTarget);
        if (el) textToCopy = el.textContent.trim();
      } else {
        const pre = btn.closest('.code-snippet-wrap')?.querySelector('code, pre') || btn.closest('.step-body')?.querySelector('code');
        if (pre) textToCopy = pre.textContent.trim();
      }

      if (textToCopy) {
        navigator.clipboard.writeText(textToCopy).then(() => {
          showToast('Copied to clipboard!');
        }).catch(() => {
          showToast('Failed to copy to clipboard.');
        });
      }
    });
  });

  function showToast(msg) {
    if (!toast) return;
    toast.textContent = msg;
    toast.classList.add('show');
    setTimeout(() => {
      toast.classList.remove('show');
    }, 2500);
  }
}

function escapeHtml(str) {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}
