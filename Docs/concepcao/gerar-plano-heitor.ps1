param(
    [string]$OutputDir = (Join-Path $PSScriptRoot "saida")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Set-HeaderStyle {
    param($range)
    $range.Font.Bold = $true
    $range.Font.Color = 16777215
    $range.Interior.Color = 39423
    $range.HorizontalAlignment = -4108
    $range.VerticalAlignment = -4108
}

function Set-TitleStyle {
    param($range)
    $range.Font.Bold = $true
    $range.Font.Size = 20
    $range.Font.Color = 16777215
    $range.Interior.Color = 255
    $range.HorizontalAlignment = -4108
    $range.VerticalAlignment = -4108
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$excel = $null
$workbook = $null

try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false

    $workbook = $excel.Workbooks.Add()

    $dashboard = $workbook.Worksheets.Item(1)
    $dashboard.Name = "Dashboard"

    $diario = $workbook.Worksheets.Add()
    $diario.Name = "Diario"

    $notas = $workbook.Worksheets.Add()
    $notas.Name = "Notas"

    $ranking = $workbook.Worksheets.Add()
    $ranking.Name = "Ranking"

    $regras = $workbook.Worksheets.Add()
    $regras.Name = "Regras"

    # ---------------------
    # Dashboard
    # ---------------------
    $dashboard.Range("A1:H2").Merge()
    $dashboard.Range("A1").Value2 = "PLANO EPICO DE CRESCIMENTO E ESTUDOS - HEITOR"
    Set-TitleStyle -range $dashboard.Range("A1")

    $dashboard.Range("A4").Value2 = "Meta Final"
    $dashboard.Range("B4").Value2 = "Nintendo Switch"
    $dashboard.Range("A5").Value2 = "Total Acumulado"
    $dashboard.Range("B5").Formula = "=SUM(Diario!N:N)+SUM(Notas!D:D)+B12+B13+B14"
    $dashboard.Range("A6").Value2 = "Falta para 3000"
    $dashboard.Range("B6").Formula = "=MAX(0,3000-B5)"
    $dashboard.Range("A7").Value2 = "Progresso"
    $dashboard.Range("B7").Formula = "=B5/3000"
    $dashboard.Range("B7").NumberFormat = "0.00%"

    $dashboard.Range("A9").Value2 = "Level Atual"
    $dashboard.Range("B9").Formula = '=IF(B5<300,"Level 1",IF(B5<800,"Level 2",IF(B5<1500,"Level 3",IF(B5<2000,"Level 4","Level 5"))))'
    $dashboard.Range("A10").Value2 = "Recompensa Atual"
    $dashboard.Range("B10").Formula = '=IF(B5<300,"Lanche especial",IF(B5<800,"Filme + pipoca",IF(B5<1500,"Brinquedo",IF(B5<2000,"Passeio","Nintendo Switch"))))'

    $dashboard.Range("A12").Value2 = "Bonus Chefao das Notas"
    $dashboard.Range("B12").Formula = "=IF(C12>=5,150,0)"
    $dashboard.Range("C12").Formula = "=COUNTIF(Notas!B:B,10)"
    $dashboard.Range("D12").Value2 = "qtde notas 10"

    $dashboard.Range("A13").Value2 = "Bonus Chefao da Semana"
    $dashboard.Range("B13").Formula = "=IF(C13>=7,100,0)"
    $dashboard.Range("C13").Formula = "=COUNTIF(Diario!K:K,1)"
    $dashboard.Range("D13").Value2 = "dias perfeitos"

    $dashboard.Range("A14").Value2 = "Bonus Ranking Semanal"
    $dashboard.Range("B14").Formula = "=IF(Ranking!H2=1,50,IF(Ranking!H2=2,30,IF(Ranking!H2=3,10,0)))"

    $dashboard.Range("A16").Value2 = "Barra de Progresso"
    $dashboard.Range("A17:G18").Merge()
    $dashboard.Range("A17").Formula = '=REPT("#",ROUND(B7*30,0))&REPT("-",30-ROUND(B7*30,0))'
    $dashboard.Range("A17").Font.Name = "Consolas"
    $dashboard.Range("A17").Font.Size = 16
    $dashboard.Range("A17").HorizontalAlignment = -4108
    $dashboard.Range("A17").Interior.Color = 13107
    $dashboard.Range("A17").Font.Color = 5287936

    $dashboard.Range("A4:A17").Font.Bold = $true
    $dashboard.Range("A4:D17").Borders.LineStyle = 1
    $dashboard.Range("A4:D17").Interior.Color = 14408667
    $dashboard.Range("A1:H20").Columns.AutoFit() | Out-Null

    # ---------------------
    # Diario
    # ---------------------
    $diario.Range("A1:N1").Value2 = @(
        "Data","Dormiu cedo","Cafe da manha","Pre-treino","Pos-treino","Pouca tela","Estudo do dia",
        "R$ Habitos","Dia perfeito","Streak","Bonus Combo","Penalidade","Observacoes","Total Dia"
    )
    Set-HeaderStyle -range $diario.Range("A1:N1")

    for ($r = 2; $r -le 32; $r++) {
        $diario.Cells.Item($r,1).Formula = "=DATE(YEAR(TODAY()),MONTH(TODAY()),ROW()-1)"
        $diario.Cells.Item($r,1).NumberFormat = "dd/mm/yyyy"

        $diario.Cells.Item($r,8).Formula = "=IF(B$r=""Sim"",2,0)+IF(C$r=""Sim"",1,0)+IF(D$r=""Sim"",1,0)+IF(E$r=""Sim"",2,0)+IF(F$r=""Sim"",1,0)+IF(G$r=""Sim"",2,0)"
        $diario.Cells.Item($r,9).Formula = "=IF(COUNTIF(B$r:G$r,""Sim"")=6,1,0)"

        if ($r -eq 2) {
            $diario.Cells.Item($r,10).Formula = "=IF(I$r=1,1,0)"
        }
        else {
            $diario.Cells.Item($r,10).Formula = "=IF(I$r=1,J" + ($r-1) + "+1,0)"
        }

        $diario.Cells.Item($r,11).Formula = "=IF(J$r=14,40,IF(J$r=7,15,IF(J$r=3,5,0)))"
        $diario.Cells.Item($r,12).Formula = "=IF(COUNTIF(B$r:G$r,""Sim"")=0,-2,0)"
        $diario.Cells.Item($r,14).Formula = "=H$r+K$r+L$r"
    }

    $simNaoRange = $diario.Range("B2:G32")
    $simNaoRange.Validation.Delete()
    $simNaoRange.Validation.Add(3,1,1,"Sim,Nao") | Out-Null
    $simNaoRange.Validation.IgnoreBlank = $true
    $simNaoRange.Validation.InCellDropdown = $true

    $diario.Range("A1:N32").Borders.LineStyle = 1
    $diario.Range("A2:A32").Interior.Color = 15921906
    $diario.Range("H2:N32").Interior.Color = 13434879
    $diario.Range("A1:N1").RowHeight = 24
    $diario.Columns.AutoFit() | Out-Null

    # ---------------------
    # Notas
    # ---------------------
    $notas.Range("A1:D1").Value2 = @("Disciplina","Nota (0-10)","Data","R$ Ganho")
    Set-HeaderStyle -range $notas.Range("A1:D1")

    for ($r = 2; $r -le 40; $r++) {
        $notas.Cells.Item($r,4).Formula = "=IF(B$r=10,40,IF(B$r>=9,30,IF(B$r>=8,20,0)))"
    }

    $notaRange = $notas.Range("B2:B40")
    $notaRange.Validation.Delete()
    $notaRange.Validation.Add(1,1,1,"0","10") | Out-Null

    $notas.Range("A1:D40").Borders.LineStyle = 1
    $notas.Range("A2:A40").Interior.Color = 15395562
    $notas.Range("B2:D40").Interior.Color = 14671839
    $notas.Columns.AutoFit() | Out-Null

    # ---------------------
    # Ranking
    # ---------------------
    $ranking.Range("A1:H1").Value2 = @("Nome","Dias perfeitos","Habitos completos","Estudos feitos","XP Total","Posicao","Bonus","Posicao Heitor")
    Set-HeaderStyle -range $ranking.Range("A1:H1")

    $ranking.Range("A2:A8").Value2 = @("Heitor","Jogador 2","Jogador 3","Jogador 4","Jogador 5","Jogador 6","Jogador 7")
    for ($r = 2; $r -le 8; $r++) {
        $ranking.Cells.Item($r,5).Formula = "=B$r*30+C$r*10+D$r*20"
    }

    $ranking.Range("F2").Formula = "=RANK(E2,E2:E8,0)"
    $ranking.Range("G2").Formula = "=IF(F2=1,50,IF(F2=2,30,IF(F2=3,10,0)))"
    $ranking.Range("H2").Formula = "=F2"

    $ranking.Range("A1:H8").Borders.LineStyle = 1
    $ranking.Range("A2:A8").Interior.Color = 13684944
    $ranking.Range("B2:H8").Interior.Color = 15921906
    $ranking.Columns.AutoFit() | Out-Null

    # ---------------------
    # Regras
    # ---------------------
    $regras.Range("A1:D1").Value2 = @("Categoria","Regra","Valor","Observacao")
    Set-HeaderStyle -range $regras.Range("A1:D1")

    $rules = @(
        @("Habito","Dormir cedo",2,""),
        @("Habito","Cafe da manha",1,""),
        @("Habito","Pre-treino",1,""),
        @("Habito","Pos-treino",2,""),
        @("Habito","Pouca tela a noite",1,""),
        @("Habito","Estudo do dia",2,""),
        @("Notas","Nota >= 8",20,""),
        @("Notas","Nota 9",30,""),
        @("Notas","Nota 10",40,"Jackpot"),
        @("Combo","3 dias seguidos",5,"Todos os habitos"),
        @("Combo","7 dias seguidos",15,"Todos os habitos"),
        @("Combo","14 dias seguidos",40,"Todos os habitos"),
        @("Penalidade","Nao fez nada",-2,""),
        @("Chefao","5 notas 10",150,"Chefao das Notas"),
        @("Chefao","7 dias perfeitos",100,"Chefao da Semana")
    )

    $row = 2
    foreach ($rule in $rules) {
        $regras.Cells.Item($row,1).Value2 = $rule[0]
        $regras.Cells.Item($row,2).Value2 = $rule[1]
        $regras.Cells.Item($row,3).Value2 = $rule[2]
        $regras.Cells.Item($row,4).Value2 = $rule[3]
        $row++
    }

    $regras.Range("A1:D16").Borders.LineStyle = 1
    $regras.Range("A2:A16").Interior.Color = 14737632
    $regras.Range("B2:D16").Interior.Color = 16049391
    $regras.Columns.AutoFit() | Out-Null

    foreach ($ws in @($dashboard,$diario,$notas,$ranking,$regras)) {
        $ws.Tab.Color = 255
        $ws.PageSetup.Orientation = 2
        $ws.PageSetup.Zoom = $false
        $ws.PageSetup.FitToPagesWide = 1
        $ws.PageSetup.FitToPagesTall = $false
    }

    $xlsxPath = Join-Path $OutputDir "Plano_Gamificado_Heitor.xlsx"
    $pdfPath = Join-Path $OutputDir "Plano_Gamificado_Heitor.pdf"

    $workbook.SaveAs($xlsxPath, 51)
    $workbook.ExportAsFixedFormat(0, $pdfPath)

    Write-Host "Arquivos gerados com sucesso:"
    Write-Host $xlsxPath
    Write-Host $pdfPath
}
catch {
    Write-Warning "Nao foi possivel automatizar pelo Excel COM. Erro: $($_.Exception.Message)"

    $fallbackHtml = @'
<!doctype html>
<html lang='pt-BR'>
<head>
<meta charset='utf-8'>
<meta name='viewport' content='width=device-width, initial-scale=1'>
<title>Plano Epico de Crescimento - Heitor</title>
<style>
:root {
  --bg:#130f1f;
  --panel:#2b1f3f;
  --panel2:#40245a;
  --gold:#f6c544;
  --lava:#ff6b2d;
  --mint:#7ef8ba;
  --text:#f7f2ff;
}
* { box-sizing:border-box; }
body {
  margin:0;
  font-family: "Trebuchet MS", Verdana, sans-serif;
  color:var(--text);
  background: radial-gradient(circle at top, #2e1e4d 0%, #130f1f 55%, #0e0a17 100%);
}
.container { max-width:1100px; margin:24px auto; padding:16px; }
.hero {
  background: linear-gradient(120deg, var(--panel2), #24193b);
  border:3px solid var(--gold);
  border-radius:20px;
  padding:18px;
  box-shadow:0 0 18px rgba(246,197,68,.35);
}
h1 { margin:0 0 8px; color:var(--gold); font-size:34px; }
.grid { display:grid; grid-template-columns:repeat(2,1fr); gap:14px; margin-top:16px; }
.card {
  background: linear-gradient(160deg, #2a2040, #1f1730);
  border:2px solid #6e4ea4;
  border-radius:14px;
  padding:14px;
}
.card h2 { margin:0 0 8px; color:#ffdd77; font-size:20px; }
.bar {
  height:26px;
  border:2px solid #8c6bc2;
  border-radius:999px;
  background:#1b1328;
  overflow:hidden;
}
.fill {
  width:0%;
  height:100%;
  background: linear-gradient(90deg,#ff8a3d,#ffd15a);
}
table { width:100%; border-collapse:collapse; margin-top:8px; }
th,td { border:1px solid #7b61a9; padding:8px; text-align:left; }
th { background:#3a2857; color:#ffe29a; }
.badge { background:#4b2f71; border:1px solid #9f7bda; padding:4px 8px; border-radius:999px; display:inline-block; margin-right:6px; }
.small { opacity:.9; font-size:13px; }
</style>
</head>
<body>
  <div class='container'>
    <section class='hero'>
      <h1>PLANO EPICO DE CRESCIMENTO E ESTUDOS - HEITOR</h1>
      <p class='small'>Objetivo final: acumular R$3000 para desbloquear o Nintendo Switch.</p>
      <div class='bar'><div class='fill'></div></div>
      <p><strong>Progresso inicial:</strong> R$0 / R$3000</p>
      <span class='badge'>Level 1: R$0 - R$300</span>
      <span class='badge'>Level 2: R$300 - R$800</span>
      <span class='badge'>Level 3: R$800 - R$1500</span>
      <span class='badge'>Level 4: R$1500 - R$2000</span>
      <span class='badge'>Level 5: R$2000 - R$3000</span>
    </section>

    <section class='grid'>
      <article class='card'>
        <h2>Habitos Diarios</h2>
        <table>
          <tr><th>Acao</th><th>Recompensa</th></tr>
          <tr><td>Dormir cedo</td><td>+R$2</td></tr>
          <tr><td>Cafe da manha</td><td>+R$1</td></tr>
          <tr><td>Pre-treino</td><td>+R$1</td></tr>
          <tr><td>Pos-treino</td><td>+R$2</td></tr>
          <tr><td>Pouca tela a noite</td><td>+R$1</td></tr>
          <tr><td>Estudo do dia</td><td>+R$2</td></tr>
        </table>
      </article>

      <article class='card'>
        <h2>Notas e Bosses</h2>
        <table>
          <tr><th>Meta</th><th>Recompensa</th></tr>
          <tr><td>Nota >= 8</td><td>+R$20</td></tr>
          <tr><td>Nota 9</td><td>+R$30</td></tr>
          <tr><td>Nota 10</td><td>+R$40</td></tr>
          <tr><td>Chefao das Notas (5 notas 10)</td><td>+R$150</td></tr>
          <tr><td>Chefao da Semana (7 dias perfeitos)</td><td>+R$100</td></tr>
        </table>
      </article>

      <article class='card'>
        <h2>Combos</h2>
        <p>3 dias perfeitos: +R$5</p>
        <p>7 dias perfeitos: +R$15</p>
        <p>14 dias perfeitos: +R$40</p>
        <p class='small'>Se quebrar sequencia, combo zera.</p>
      </article>

      <article class='card'>
        <h2>Penalidades e Ranking</h2>
        <p>Nao fez nada no dia: -R$2</p>
        <p>Ranking semanal:</p>
        <p>TOP 1 +R$50 | TOP 2 +R$30 | TOP 3 +R$10</p>
      </article>
    </section>
  </div>
</body>
</html>
'@

    $htmlPath = Join-Path $OutputDir "Plano_Gamificado_Heitor_Fallback.html"
    Set-Content -LiteralPath $htmlPath -Value $fallbackHtml -Encoding UTF8

    Write-Host "Fallback HTML gerado:"
    Write-Host $htmlPath
}
finally {
    if ($workbook -ne $null) {
        $workbook.Close($true)
    }

    if ($excel -ne $null) {
        $excel.Quit()
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
    }

    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
