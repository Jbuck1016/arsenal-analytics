# Visualization baselines

These images are generated from live Supabase-backed Player, Team and Match
plots at desktop, tablet and phone widths. Secondary coverage includes Player
Compare, Team Rankings, Insights and Sequences. The set includes dark, light
and monochrome renders plus the first rendered page of each PNG/PDF export path.
Update after an intentional design change:

```powershell
$env:NODE_PATH = 'C:\Users\jbuck\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\node_modules'
node pipeline/tools/visual_regression.js --update
node pipeline/tools/visual_regression.js
```

The comparison run fails above a 0.2% changed-pixel threshold and writes
`.received.png` and `.diff.png` evidence beside the baseline.
