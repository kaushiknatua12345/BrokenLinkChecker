#Requires -Version 5.1
<#
.SYNOPSIS
    Confluence Broken Link Checker - Desktop Application
.DESCRIPTION
    Scans a Confluence page for broken links and optionally posts results as a page comment.
    Share this script with your team - runs on any Windows machine with PowerShell 5.1+.
.NOTES
    No external dependencies required. Uses Windows Forms for the GUI.
#>

# --- Error Logging ---
$logFile = Join-Path $PSScriptRoot "BrokenLinkChecker.log"
Start-Transcript -Path $logFile -Force -ErrorAction SilentlyContinue
Write-Host "[$(Get-Date)] Script starting..."

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Theme & Constants ---
$primaryColor   = [System.Drawing.Color]::FromArgb(0, 82, 204)     # Atlassian blue
$successColor   = [System.Drawing.Color]::FromArgb(0, 135, 90)
$errorColor     = [System.Drawing.Color]::FromArgb(222, 53, 11)
$warningColor   = [System.Drawing.Color]::FromArgb(255, 153, 31)
$bgColor        = [System.Drawing.Color]::FromArgb(244, 245, 247)
$cardColor      = [System.Drawing.Color]::White
$textColor      = [System.Drawing.Color]::FromArgb(23, 43, 77)
$mutedColor     = [System.Drawing.Color]::FromArgb(107, 119, 140)
$fontFamily     = "Segoe UI"

# --- Main Form ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Confluence Broken Link Checker"
$form.Size = New-Object System.Drawing.Size(920, 720)
$form.StartPosition = "CenterScreen"
$form.BackColor = $bgColor
$form.Font = New-Object System.Drawing.Font($fontFamily, 9)
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.Icon = [System.Drawing.SystemIcons]::Shield

# --- Header Panel ---
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Dock = "Top"
$headerPanel.Height = 60
$headerPanel.BackColor = $primaryColor

$headerLabel = New-Object System.Windows.Forms.Label
$headerLabel.Text = "  Confluence Broken Link Checker"
$headerLabel.Font = New-Object System.Drawing.Font($fontFamily, 15, [System.Drawing.FontStyle]::Bold)
$headerLabel.ForeColor = [System.Drawing.Color]::White
$headerLabel.Dock = "Fill"
$headerLabel.TextAlign = "MiddleLeft"
$headerPanel.Controls.Add($headerLabel)
$form.Controls.Add($headerPanel)

# --- Credentials Group ---
$credGroup = New-Object System.Windows.Forms.GroupBox
$credGroup.Text = "Confluence Credentials"
$credGroup.Location = New-Object System.Drawing.Point(15, 75)
$credGroup.Size = New-Object System.Drawing.Size(875, 130)
$credGroup.BackColor = $cardColor
$credGroup.ForeColor = $textColor
$credGroup.Font = New-Object System.Drawing.Font($fontFamily, 9, [System.Drawing.FontStyle]::Bold)

$lblBase = New-Object System.Windows.Forms.Label
$lblBase.Text = "Base URL:"
$lblBase.Location = New-Object System.Drawing.Point(15, 28)
$lblBase.Size = New-Object System.Drawing.Size(100, 22)
$lblBase.Font = New-Object System.Drawing.Font($fontFamily, 9)

$txtBaseUrl = New-Object System.Windows.Forms.TextBox
$txtBaseUrl.Location = New-Object System.Drawing.Point(120, 25)
$txtBaseUrl.Size = New-Object System.Drawing.Size(735, 22)
$txtBaseUrl.Font = New-Object System.Drawing.Font($fontFamily, 9)
$txtBaseUrl.ReadOnly = $true
$txtBaseUrl.BackColor = [System.Drawing.Color]::FromArgb(235, 236, 240)
$txtBaseUrl.Text = if ($env:CONFLUENCE_BASE_URL) { ($env:CONFLUENCE_BASE_URL -replace '/wiki.*$', '/wiki') } else { "https://yourcompany.atlassian.net/wiki" }

$lblEmail = New-Object System.Windows.Forms.Label
$lblEmail.Text = "Hyland Email ID:"
$lblEmail.Location = New-Object System.Drawing.Point(15, 60)
$lblEmail.Size = New-Object System.Drawing.Size(100, 22)
$lblEmail.Font = New-Object System.Drawing.Font($fontFamily, 9)

$txtEmail = New-Object System.Windows.Forms.TextBox
$txtEmail.Location = New-Object System.Drawing.Point(120, 57)
$txtEmail.Size = New-Object System.Drawing.Size(735, 22)
$txtEmail.Font = New-Object System.Drawing.Font($fontFamily, 9)

$lblToken = New-Object System.Windows.Forms.Label
$lblToken.Text = "API Token:"
$lblToken.Location = New-Object System.Drawing.Point(15, 92)
$lblToken.Size = New-Object System.Drawing.Size(100, 22)
$lblToken.Font = New-Object System.Drawing.Font($fontFamily, 9)

$txtToken = New-Object System.Windows.Forms.TextBox
$txtToken.Location = New-Object System.Drawing.Point(120, 89)
$txtToken.Size = New-Object System.Drawing.Size(735, 22)
$txtToken.Font = New-Object System.Drawing.Font($fontFamily, 9)
$txtToken.ReadOnly = $false
$txtToken.Enabled = $true
$txtToken.BackColor = [System.Drawing.Color]::White
$txtToken.PasswordChar = [char]0x2022  # bullet character mask
$txtToken.Text = if ($env:CONFLUENCE_API_TOKEN) { $env:CONFLUENCE_API_TOKEN } else { "" }

$credGroup.Controls.AddRange(@($lblBase, $txtBaseUrl, $lblEmail, $txtEmail, $lblToken, $txtToken))
$form.Controls.Add($credGroup)

# --- Page URL Group ---
$pageGroup = New-Object System.Windows.Forms.GroupBox
$pageGroup.Text = "Page to Scan"
$pageGroup.Location = New-Object System.Drawing.Point(15, 215)
$pageGroup.Size = New-Object System.Drawing.Size(875, 65)
$pageGroup.BackColor = $cardColor
$pageGroup.ForeColor = $textColor
$pageGroup.Font = New-Object System.Drawing.Font($fontFamily, 9, [System.Drawing.FontStyle]::Bold)

$lblPage = New-Object System.Windows.Forms.Label
$lblPage.Text = "Page URL:"
$lblPage.Location = New-Object System.Drawing.Point(15, 28)
$lblPage.Size = New-Object System.Drawing.Size(100, 22)
$lblPage.Font = New-Object System.Drawing.Font($fontFamily, 9)

$txtPageUrl = New-Object System.Windows.Forms.TextBox
$txtPageUrl.Location = New-Object System.Drawing.Point(120, 25)
$txtPageUrl.Size = New-Object System.Drawing.Size(735, 22)
$txtPageUrl.Font = New-Object System.Drawing.Font($fontFamily, 9)
$txtPageUrl.ReadOnly = $false
$txtPageUrl.Enabled = $true
$txtPageUrl.BackColor = [System.Drawing.Color]::White

$pageGroup.Controls.AddRange(@($lblPage, $txtPageUrl))
$form.Controls.Add($pageGroup)

# --- Buttons ---
$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text = "Link and Page Checker"
$btnScan.Location = New-Object System.Drawing.Point(15, 292)
$btnScan.Size = New-Object System.Drawing.Size(175, 38)
$btnScan.BackColor = $primaryColor
$btnScan.ForeColor = [System.Drawing.Color]::White
$btnScan.FlatStyle = "Flat"
$btnScan.Font = New-Object System.Drawing.Font($fontFamily, 9, [System.Drawing.FontStyle]::Bold)
$btnScan.Cursor = [System.Windows.Forms.Cursors]::Hand

$btnPostComment = New-Object System.Windows.Forms.Button
$btnPostComment.Text = "Post to Confluence"
$btnPostComment.Location = New-Object System.Drawing.Point(195, 292)
$btnPostComment.Size = New-Object System.Drawing.Size(170, 38)
$btnPostComment.BackColor = $successColor
$btnPostComment.ForeColor = [System.Drawing.Color]::White
$btnPostComment.FlatStyle = "Flat"
$btnPostComment.Font = New-Object System.Drawing.Font($fontFamily, 9, [System.Drawing.FontStyle]::Bold)
$btnPostComment.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnPostComment.Enabled = $false

$btnCreateJira = New-Object System.Windows.Forms.Button
$btnCreateJira.Text = "Create JIRA Tickets"
$btnCreateJira.Location = New-Object System.Drawing.Point(370, 292)
$btnCreateJira.Size = New-Object System.Drawing.Size(170, 38)
$btnCreateJira.BackColor = $warningColor
$btnCreateJira.ForeColor = [System.Drawing.Color]::White
$btnCreateJira.FlatStyle = "Flat"
$btnCreateJira.Font = New-Object System.Drawing.Font($fontFamily, 9, [System.Drawing.FontStyle]::Bold)
$btnCreateJira.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnCreateJira.Enabled = $false

$btnExport = New-Object System.Windows.Forms.Button
$btnExport.Text = "Export CSV"
$btnExport.Location = New-Object System.Drawing.Point(545, 292)
$btnExport.Size = New-Object System.Drawing.Size(115, 38)
$btnExport.BackColor = $mutedColor
$btnExport.ForeColor = [System.Drawing.Color]::White
$btnExport.FlatStyle = "Flat"
$btnExport.Font = New-Object System.Drawing.Font($fontFamily, 9, [System.Drawing.FontStyle]::Bold)
$btnExport.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnExport.Enabled = $false

$form.Controls.AddRange(@($btnScan, $btnPostComment, $btnCreateJira, $btnExport))

# --- Status Bar ---
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(800, 295)
$statusLabel.Size = New-Object System.Drawing.Size(85, 38)
$statusLabel.Font = New-Object System.Drawing.Font($fontFamily, 8)
$statusLabel.ForeColor = $mutedColor
$statusLabel.TextAlign = "MiddleRight"
$statusLabel.Text = "Ready"
$form.Controls.Add($statusLabel)

# --- Progress Bar ---
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(15, 338)
$progressBar.Size = New-Object System.Drawing.Size(875, 8)
$progressBar.Style = "Continuous"
$progressBar.Visible = $false
$form.Controls.Add($progressBar)

# --- Results DataGridView ---
$resultsGroup = New-Object System.Windows.Forms.GroupBox
$resultsGroup.Text = "Scan Results"
$resultsGroup.Location = New-Object System.Drawing.Point(15, 352)
$resultsGroup.Size = New-Object System.Drawing.Size(875, 280)
$resultsGroup.BackColor = $cardColor
$resultsGroup.ForeColor = $textColor
$resultsGroup.Font = New-Object System.Drawing.Font($fontFamily, 9, [System.Drawing.FontStyle]::Bold)

$dgv = New-Object System.Windows.Forms.DataGridView
$dgv.Location = New-Object System.Drawing.Point(10, 22)
$dgv.Size = New-Object System.Drawing.Size(855, 200)
$dgv.BackgroundColor = $cardColor
$dgv.BorderStyle = "None"
$dgv.RowHeadersVisible = $false
$dgv.AllowUserToAddRows = $false
$dgv.AllowUserToDeleteRows = $false
$dgv.ReadOnly = $true
$dgv.SelectionMode = "FullRowSelect"
$dgv.AutoSizeColumnsMode = "Fill"
$dgv.AutoGenerateColumns = $false
$dgv.Font = New-Object System.Drawing.Font($fontFamily, 8.5)
$dgv.ColumnHeadersDefaultCellStyle.BackColor = $primaryColor
$dgv.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::White
$dgv.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font($fontFamily, 9, [System.Drawing.FontStyle]::Bold)
$dgv.EnableHeadersVisualStyles = $false
$dgv.ColumnHeadersHeight = 32

$colNum = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colNum.Name = "No"; $colNum.HeaderText = "#"; $colNum.Width = 35; $colNum.FillWeight = 6
$colUrl = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colUrl.Name = "URL"; $colUrl.HeaderText = "URL"; $colUrl.FillWeight = 42
$colPageTitle = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colPageTitle.Name = "PageTitle"; $colPageTitle.HeaderText = "Destination Page Title"; $colPageTitle.FillWeight = 35
$colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colStatus.Name = "Status"; $colStatus.HeaderText = "Status"; $colStatus.Width = 65; $colStatus.FillWeight = 9
$colResult = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colResult.Name = "Result"; $colResult.HeaderText = "Result"; $colResult.FillWeight = 13
[void]$dgv.Columns.Add($colNum)
[void]$dgv.Columns.Add($colUrl)
[void]$dgv.Columns.Add($colPageTitle)
[void]$dgv.Columns.Add($colStatus)
[void]$dgv.Columns.Add($colResult)

# --- Summary Label ---
$lblSummary = New-Object System.Windows.Forms.Label
$lblSummary.Location = New-Object System.Drawing.Point(10, 230)
$lblSummary.Size = New-Object System.Drawing.Size(855, 40)
$lblSummary.Font = New-Object System.Drawing.Font($fontFamily, 9)
$lblSummary.ForeColor = $textColor
$lblSummary.Text = ""

$resultsGroup.Controls.AddRange(@($dgv, $lblSummary))
$form.Controls.Add($resultsGroup)

# --- Footer ---
$footerLabel = New-Object System.Windows.Forms.Label
$footerLabel.Location = New-Object System.Drawing.Point(15, 640)
$footerLabel.Size = New-Object System.Drawing.Size(875, 20)
$footerLabel.Font = New-Object System.Drawing.Font($fontFamily, 7.5)
$footerLabel.ForeColor = $mutedColor
$footerLabel.TextAlign = "MiddleCenter"
$footerLabel.Text = "Confluence Broken Link Checker v2.0  |  Powered by Confluence REST API  |  Rate-limited to 1 req/sec"
$form.Controls.Add($footerLabel)

# --- Shared State ---
$script:scanResults = @()
$script:pageId = $null
$script:pageTitle = $null

# --- Helper: Get Auth Headers ---
function Get-AuthHeaders {
    $email = $txtEmail.Text.Trim()
    $token = $txtToken.Text.Trim()
    $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${email}:${token}"))
    return @{
        "Authorization" = "Basic $auth"
        "Content-Type"  = "application/json"
        "Accept"        = "application/json"
    }
}

# --- Helper: Resolve Page URL to Page ID ---
function Resolve-PageId {
    param([string]$Url, [hashtable]$Headers)

    # If URL already contains /pages/<id>/, extract directly
    if ($Url -match '/pages/(\d+)') {
        return $Matches[1]
    }

    # If URL is just a numeric page ID, use it directly
    if ($Url -match '^\d+$') {
        return $Url
    }

    $baseUrl = $txtBaseUrl.Text.Trim().TrimEnd('/')

    # Try extracting tinyurl identifier and decode page ID directly (no HTTP needed)
    if ($Url -match '/x/([A-Za-z0-9_-]+)') {
        $tinyId = $Matches[1]
        Write-Host "[$(Get-Date)] Resolving tiny URL identifier: $tinyId"

        # Decode base64-encoded page ID (Confluence stores it as little-endian bytes)
        try {
            $b64 = $tinyId.Replace('-', '+').Replace('_', '/')
            $b64 = $b64.PadRight([Math]::Ceiling($b64.Length / 4) * 4, '=')
            $bytes = [Convert]::FromBase64String($b64)
            $decodedId = [long]0
            for ($i = $bytes.Length - 1; $i -ge 0; $i--) {
                $decodedId = ($decodedId * 256) + $bytes[$i]
            }
            if ($decodedId -gt 0) {
                Write-Host "[$(Get-Date)] Decoded tiny URL to page ID: $decodedId"
                # Try to verify but return the ID regardless - page fetch will give proper error
                try {
                    $verifyResp = Invoke-RestMethod -Uri "${baseUrl}/rest/api/content/${decodedId}?expand=version" -Headers $Headers -ErrorAction Stop
                    Write-Host "[$(Get-Date)] Verified page exists: $($verifyResp.title)"
                    return $decodedId.ToString()
                } catch {
                    Write-Host "[$(Get-Date)] Page ID $decodedId not found via API, continuing with other approaches..."
                }
                return $decodedId.ToString()
            }
        } catch {
            Write-Host "[$(Get-Date)] Base64 decode failed: $($_.Exception.Message)"
        }

        # Fallback: tinyurl.action with HttpWebRequest redirect
        try {
            $req = [System.Net.HttpWebRequest]::Create("${baseUrl}/pages/tinyurl.action?urlIdentifier=$tinyId")
            $req.Method = "GET"
            $req.AllowAutoRedirect = $false
            $req.Timeout = 15000
            $req.Headers.Add("Authorization", $Headers["Authorization"])
            $resp = $req.GetResponse()
            $loc = $resp.Headers["Location"]
            $resp.Close()
            if ($loc -match '/pages/(\d+)') { return $Matches[1] }
        } catch [System.Net.WebException] {
            $webResp = $_.Exception.Response
            if ($webResp) {
                $loc = $webResp.Headers["Location"]
                $webResp.Close()
                if ($loc -match '/pages/(\d+)') { return $Matches[1] }
            }
        } catch {}

        # If all approaches failed, show a helpful error
        throw "Could not resolve the tiny URL. Please use the full page URL instead.`n`nTo get the full URL: Open the page in your browser, click the '...' menu > 'Copy link', and paste the full URL here.`n`nThe full URL should look like:`nhttps://hyland.atlassian.net/wiki/spaces/{space}/pages/{pageId}/{title}"
    }

    # Handle full page URLs: /wiki/spaces/{space}/pages/{id}/{title}
    if ($Url -match '/spaces/[^/]+/pages/(\d+)') {
        return $Matches[1]
    }

    # Use .NET HttpWebRequest to manually follow redirects
    $currentUrl = $Url
    for ($i = 0; $i -lt 6; $i++) {
        try {
            $req = [System.Net.HttpWebRequest]::Create($currentUrl)
            $req.Method = "GET"
            $req.AllowAutoRedirect = $false
            $req.Timeout = 15000
            $req.Headers.Add("Authorization", $Headers["Authorization"])
            $req.Accept = "application/json"
            $resp = $req.GetResponse()
            $statusCode = [int]$resp.StatusCode
            $loc = $resp.Headers["Location"]
            $resp.Close()
            if ($statusCode -ge 300 -and $statusCode -lt 400 -and $loc) {
                if ($loc -notmatch '^https?://') {
                    $uri = [System.Uri]$currentUrl
                    $loc = "$($uri.Scheme)://$($uri.Host)$loc"
                }
                $currentUrl = $loc
                if ($currentUrl -match '/pages/(\d+)') { return $Matches[1] }
                continue
            }
            break
        } catch [System.Net.WebException] {
            $webResp = $_.Exception.Response
            if ($webResp) {
                $statusCode = [int]$webResp.StatusCode
                $loc = $webResp.Headers["Location"]
                $webResp.Close()
                if ($statusCode -ge 300 -and $statusCode -lt 400 -and $loc) {
                    if ($loc -notmatch '^https?://') {
                        $uri = [System.Uri]$currentUrl
                        $loc = "$($uri.Scheme)://$($uri.Host)$loc"
                    }
                    $currentUrl = $loc
                    if ($currentUrl -match '/pages/(\d+)') { return $Matches[1] }
                    continue
                }
            }
            break
        } catch { break }
    }

    # Fallback: try search API with the URL slug
    if ($currentUrl -match '/pages/\d+/(.+)$') {
        $title = [System.Uri]::UnescapeDataString($Matches[1]) -replace '\+', ' '
        $searchUrl = "${baseUrl}/rest/api/content?title=$([System.Uri]::EscapeDataString($title))&expand=version"
        try {
            $sr = Invoke-RestMethod -Uri $searchUrl -Headers $Headers -ErrorAction Stop
            if ($sr.results.Count -gt 0) { return $sr.results[0].id }
        } catch {}
    }

    return $null
}

# --- Helper: Extract links from HTML ---
function Get-LinksFromHtml {
    param([string]$Html)

    $links = @{}
    # Match full <a> tags to capture both href and anchor text
    $aTagRegex = [regex]'<a\s[^>]*href\s*=\s*"([^"]+)"[^>]*>([\s\S]*?)</a>'
    $aMatches = $aTagRegex.Matches($Html)
    foreach ($m in $aMatches) {
        $href = $m.Groups[1].Value
        $anchorText = $m.Groups[2].Value -replace '<[^>]+>', '' # strip nested HTML tags
        $anchorText = [System.Net.WebUtility]::HtmlDecode($anchorText.Trim())
        # Skip mailto, javascript, and same-page anchors
        if ($href -match '^(mailto:|javascript:|#$|#[^/])') { continue }
        if ($href -match '^\s*$') { continue }
        # Keep first anchor text found for each unique href
        if (-not $links.ContainsKey($href)) {
            $links[$href] = $anchorText
        }
    }
    # Also catch bare href= not inside full <a>...</a> tags
    $hrefOnly = [regex]'href\s*=\s*"([^"]+)"'
    $hrefMatches = $hrefOnly.Matches($Html)
    foreach ($m in $hrefMatches) {
        $href = $m.Groups[1].Value
        if ($href -match '^(mailto:|javascript:|#$|#[^/])') { continue }
        if ($href -match '^\s*$') { continue }
        if (-not $links.ContainsKey($href)) {
            $links[$href] = ''
        }

    }
    # Extract Confluence-specific link patterns (ri:url, ac:link, drawio macros)
    $riUrlRegex = [regex]'ri:value\s*=\s*"(https?://[^"]+)"'
    $riMatches = $riUrlRegex.Matches($Html)
    foreach ($m in $riMatches) {
        $href = $m.Groups[1].Value
        if (-not $links.ContainsKey($href)) { $links[$href] = '' }
    }

    # Extract URLs from ac:parameter tags (draw.io, embed macros)
    $acParamRegex = [regex]'<ac:parameter[^>]*ac:name="(?:url|diagramUrl|baseUrl|link)"[^>]*>(https?://[^<]+)</ac:parameter>'
    $acMatches = $acParamRegex.Matches($Html)
    foreach ($m in $acMatches) {
        $href = $m.Groups[1].Value.Trim()
        if ($href -and -not $links.ContainsKey($href)) { $links[$href] = '' }
    }

    # Extract URLs from data- attributes and src attributes
    $dataUrlRegex = [regex]'(?:data-[a-z-]*url|data-src|src)\s*=\s*"(https?://[^"]+)"'
    $dataMatches = $dataUrlRegex.Matches($Html)
    foreach ($m in $dataMatches) {
        $href = $m.Groups[1].Value
        if (-not $links.ContainsKey($href)) { $links[$href] = '' }
    }

    # Catch draw.io / diagrams.net URLs anywhere in the HTML
    $drawioRegex = [regex]'(https?://(?:app\.diagrams\.net|draw\.io|viewer\.diagrams\.net)[^\s"<>]+)'
    $drawioMatches = $drawioRegex.Matches($Html)
    foreach ($m in $drawioMatches) {
        $href = $m.Groups[1].Value
        if (-not $links.ContainsKey($href)) { $links[$href] = 'draw.io diagram' }
    }

    return $links
}

# --- Helper: Check a single URL ---
function Test-LinkHealth {
    param(
        [string]$Url,
        [hashtable]$AuthHeaders = $null
    )

    # ---------------------------------------------------------------
    # Atlassian / Confluence URLs
    # Invoke-WebRequest on Confluence page URLs gets SAML-redirected
    # even when Basic auth headers are supplied, producing false BROKEN
    # results.  Use the Confluence REST API instead — it correctly
    # accepts the email:token Basic auth credentials.
    # ---------------------------------------------------------------
    if ($Url -match 'atlassian\.net' -and $AuthHeaders) {

        # Derive the wiki base URL needed for REST API calls
        $apiBase = if ($Url -match '(https://[^/]+/wiki)') { $Matches[1] }
                   elseif ($Url -match '(https://[^/]+)')   { "$($Matches[1])/wiki" }
                   else                                      { "" }

        # Extract page ID from URL — covers all Confluence URL formats
        $pageId = $null
        if    ($Url -match '/pages/(\d+)')                  { $pageId = $Matches[1] }
        elseif ($Url -match '/spaces/[^/]+/pages/(\d+)')    { $pageId = $Matches[1] }
        elseif ($Url -match '[?&]pageId=(\d+)')             { $pageId = $Matches[1] }   # legacy viewpage.action
        if (-not $pageId) {
            try { $pageId = Resolve-PageId -Url $Url -Headers $AuthHeaders } catch {}
        }

        if ($pageId -and $apiBase) {
            try {
                Invoke-RestMethod -Uri "${apiBase}/rest/api/content/${pageId}" `
                    -Headers $AuthHeaders -TimeoutSec 15 -ErrorAction Stop | Out-Null
                Write-Host "[$(Get-Date)] Link OK  (API): $Url  [page $pageId]"
                return @{ Status = 200; Result = "OK" }
            } catch {
                $code = $null
                if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
                if (-not $code) { $code = "Unreachable" }
                Write-Host "[$(Get-Date)] Link FAIL (API $code): $Url"
                if ($code -eq 401 -or $code -eq 403) { return @{ Status = $code; Result = "Auth Required" } }
                return @{ Status = $code; Result = "BROKEN" }
            }
        }

        # Could not resolve URL to a page ID — page is deleted / URL is invalid
        Write-Host "[$(Get-Date)] Link FAIL (unresolvable): $Url"
        return @{ Status = 404; Result = "BROKEN" }
    }

    # ---------------------------------------------------------------
    # All other URLs — standard web request approach
    # ---------------------------------------------------------------
    # For hyland.* domains (e.g. hyland.udemy.com) include credentials
    $isHyland  = $Url -match 'hyland\.'
    $reqParams = @{ MaximumRedirection = 3; TimeoutSec = 15; UseBasicParsing = $true; ErrorAction = 'Stop' }
    if ($isHyland -and $AuthHeaders) { $reqParams['Headers'] = $AuthHeaders }

    try {
        $r    = Invoke-WebRequest -Uri $Url -Method Head @reqParams
        $code = $r.StatusCode
        if ($code -ge 200 -and $code -lt 300) { return @{ Status = $code; Result = "OK" } }
        if ($code -ge 300 -and $code -lt 400) { return @{ Status = $code; Result = "Redirect" } }
        return @{ Status = $code; Result = "Unknown" }
    } catch {
        # Some servers block HEAD — fall back to GET
        try {
            $r    = Invoke-WebRequest -Uri $Url -Method Get @reqParams
            $code = $r.StatusCode
            if ($code -ge 200 -and $code -lt 300) { return @{ Status = $code; Result = "OK" } }
            if ($code -ge 300 -and $code -lt 400) { return @{ Status = $code; Result = "Redirect" } }
            return @{ Status = $code; Result = "Unknown" }
        } catch {
            $code = $null
            if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
            if (-not $code) { $code = "Unreachable" }

            # External URL returned 401/403 — retry once with Hyland credentials
            if (($code -eq 401 -or $code -eq 403) -and $AuthHeaders -and -not $isHyland) {
                try {
                    $authR    = Invoke-WebRequest -Uri $Url -Method Get -Headers $AuthHeaders `
                        -MaximumRedirection 3 -TimeoutSec 15 -UseBasicParsing -ErrorAction Stop
                    $authCode = $authR.StatusCode
                    if ($authCode -ge 200 -and $authCode -lt 300) { return @{ Status = $authCode; Result = "OK" } }
                } catch {
                    $authCode = $null
                    if ($_.Exception.Response) { $authCode = [int]$_.Exception.Response.StatusCode }
                    if ($authCode -eq 401 -or $authCode -eq 403) { return @{ Status = $authCode; Result = "Auth Required" } }
                }
            }

            if ($code -eq 401 -or $code -eq 403) { return @{ Status = $code; Result = "Auth Required" } }
            return @{ Status = $code; Result = "BROKEN" }
        }
    }
}

# --- Helper: Find suggested replacement link ---
function Find-SuggestedLink {
    param(
        [string]$BrokenUrl,
        [string]$AnchorText,
        [hashtable]$Headers,
        [string]$BaseUrl
    )

    Write-Host "[$(Get-Date)] Searching for replacement link for: $BrokenUrl (anchor text: '$AnchorText')"

    # Determine if the broken link was originally an internal Confluence link
    $isInternalLink = $BrokenUrl -match [regex]::Escape($BaseUrl) -or $BrokenUrl -match 'atlassian\.net/wiki'

    # Strategy 1: Try common domain typo corrections
    $domainFixes = @(
        @('\.abcd\b', '.com'),
        @('\.abcd\b', '.net'),
        @('\.abcd\b', '.org'),
        @('\.con\b', '.com'),
        @('\.nte\b', '.net'),
        @('\.ocm\b', '.com'),
        @('\.cmo\b', '.com'),
        @('\.ogr\b', '.org'),
        @('\.rog\b', '.org')
    )
    foreach ($fix in $domainFixes) {
        $corrected = $BrokenUrl -replace $fix[0], $fix[1]
        if ($corrected -ne $BrokenUrl) {
            try {
                $check = Invoke-WebRequest -Uri $corrected -Method Head -MaximumRedirection 3 -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
                if ($check.StatusCode -ge 200 -and $check.StatusCode -lt 400) {
                    Write-Host "[$(Get-Date)] Found via domain fix: $corrected"
                    return $corrected
                }
            } catch {
                try {
                    $check = Invoke-WebRequest -Uri $corrected -Method Get -MaximumRedirection 3 -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
                    if ($check.StatusCode -ge 200 -and $check.StatusCode -lt 400) {
                        Write-Host "[$(Get-Date)] Found via domain fix (GET): $corrected"
                        return $corrected
                    }
                } catch {}
            }
        }
    }

    # Strategy 2: Search the WEB using anchor text
    if ($AnchorText -and $AnchorText.Length -gt 2) {
        $genericTexts = @('click here', 'here', 'link', 'read more', 'learn more', 'this', 'more', 'details')
        $isGeneric = $genericTexts -contains $AnchorText.ToLower().Trim()
        if (-not $isGeneric) {
            $searchQuery = [System.Uri]::EscapeDataString($AnchorText)

            # 2a: Search YouTube (great for video content)
            try {
                Write-Host "[$(Get-Date)] Searching YouTube by anchor text: '$AnchorText'"
                $ytResp = Invoke-WebRequest -Uri "https://www.youtube.com/results?search_query=$searchQuery" -TimeoutSec 15 -UseBasicParsing -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -ErrorAction Stop
                $videoIds = [regex]::Matches($ytResp.Content, '"videoId":"([a-zA-Z0-9_-]{11})?"')
                $seenVids = @{}
                $ytChecked = 0
                foreach ($vid in $videoIds) {
                    $videoId = $vid.Groups[1].Value
                    if ($seenVids[$videoId]) { continue }
                    $seenVids[$videoId] = $true
                    $ytUrl = "https://www.youtube.com/watch?v=$videoId"
                    $ytChecked++
                    if ($ytChecked -gt 3) { break }
                    try {
                        Write-Host "[$(Get-Date)] Verifying YouTube: $ytUrl"
                        $ytCheck = Invoke-WebRequest -Uri $ytUrl -Method Head -MaximumRedirection 3 -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
                        if ($ytCheck.StatusCode -ge 200 -and $ytCheck.StatusCode -lt 400) {
                            Write-Host "[$(Get-Date)] Found via YouTube: $ytUrl"
                            return $ytUrl
                        }
                    } catch {}
                    Start-Sleep -Milliseconds 500
                }
            } catch {
                Write-Host "[$(Get-Date)] YouTube search failed: $($_.Exception.Message)"
            }

            # 2b: Search Bing (extract from cite tags and reconstruct URLs)
            try {
                Write-Host "[$(Get-Date)] Searching Bing by anchor text: '$AnchorText'"
                $bingResp = Invoke-WebRequest -Uri "https://www.bing.com/search?q=$searchQuery" -TimeoutSec 15 -UseBasicParsing -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -ErrorAction Stop
                # Extract cite URLs (Bing puts the display URL in <cite> tags)
                $citeMatches = [regex]::Matches($bingResp.Content, '<cite[^>]*>(https?://[^<]+)</cite>')
                $bingChecked = 0
                foreach ($cm in $citeMatches) {
                    $citeUrl = $cm.Groups[1].Value -replace ' .*$', '' # trim truncated parts
                    $citeUrl = $citeUrl -replace '&amp;', '&' -replace '&#8230;.*$', '' -replace ' �.*$', ''
                    if ($citeUrl -notmatch '^https?://') { continue }
                    if ($citeUrl -match 'bing\.|microsoft\.|msn\.') { continue }
                    if ($citeUrl -eq $BrokenUrl) { continue }
                    $bingChecked++
                    if ($bingChecked -gt 3) { break }
                    try {
                        Write-Host "[$(Get-Date)] Verifying Bing candidate: $citeUrl"
                        $bCheck = Invoke-WebRequest -Uri $citeUrl -Method Head -MaximumRedirection 3 -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
                        if ($bCheck.StatusCode -ge 200 -and $bCheck.StatusCode -lt 400) {
                            Write-Host "[$(Get-Date)] Found via Bing: $citeUrl"
                            return $citeUrl
                        }
                    } catch {
                        try {
                            $bCheck = Invoke-WebRequest -Uri $citeUrl -Method Get -MaximumRedirection 3 -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
                            if ($bCheck.StatusCode -ge 200 -and $bCheck.StatusCode -lt 400) {
                                Write-Host "[$(Get-Date)] Found via Bing (GET): $citeUrl"
                                return $citeUrl
                            }
                        } catch {}
                    }
                    Start-Sleep -Milliseconds 500
                }
            } catch {
                Write-Host "[$(Get-Date)] Bing search failed: $($_.Exception.Message)"
            }

            # 2c: Search DuckDuckGo (fallback)
            try {
                Write-Host "[$(Get-Date)] Searching DuckDuckGo by anchor text: '$AnchorText'"
                $ddgResp = Invoke-WebRequest -Uri "https://html.duckduckgo.com/html/?q=$searchQuery" -TimeoutSec 15 -UseBasicParsing -ErrorAction Stop
                $ddgLinks = [regex]::Matches($ddgResp.Content, 'href="(https?://[^"]+)"')
                $ddgChecked = 0
                foreach ($dl in $ddgLinks) {
                    $candidateUrl = $dl.Groups[1].Value
                    if ($candidateUrl -match 'duckduckgo\.com/l/\?uddg=([^&]+)') {
                        $candidateUrl = [System.Uri]::UnescapeDataString($Matches[1])
                    }
                    if ($candidateUrl -match 'duckduckgo\.com|google\.com|bing\.com|yahoo\.com') { continue }
                    if ($candidateUrl -eq $BrokenUrl) { continue }
                    $ddgChecked++
                    if ($ddgChecked -gt 3) { break }
                    try {
                        Write-Host "[$(Get-Date)] Verifying DDG candidate: $candidateUrl"
                        $dCheck = Invoke-WebRequest -Uri $candidateUrl -Method Head -MaximumRedirection 3 -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
                        if ($dCheck.StatusCode -ge 200 -and $dCheck.StatusCode -lt 400) {
                            Write-Host "[$(Get-Date)] Found via DuckDuckGo: $candidateUrl"
                            return $candidateUrl
                        }
                    } catch {
                        try {
                            $dCheck = Invoke-WebRequest -Uri $candidateUrl -Method Get -MaximumRedirection 3 -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
                            if ($dCheck.StatusCode -ge 200 -and $dCheck.StatusCode -lt 400) {
                                Write-Host "[$(Get-Date)] Found via DuckDuckGo (GET): $candidateUrl"
                                return $candidateUrl
                            }
                        } catch {}
                    }
                    Start-Sleep -Milliseconds 500
                }
            } catch {
                Write-Host "[$(Get-Date)] DuckDuckGo search failed: $($_.Exception.Message)"
            }
        }
    }

    # Strategy 3: Search Confluence using ANCHOR TEXT (title match only - high confidence)
    if ($AnchorText -and $AnchorText.Length -gt 2) {
        $genericTexts = @('click here', 'here', 'link', 'read more', 'learn more', 'this', 'more', 'details')
        $isGeneric = $genericTexts -contains $AnchorText.ToLower().Trim()
        if (-not $isGeneric) {
            try {
                Write-Host "[$(Get-Date)] Searching Confluence (title) by anchor text: '$AnchorText'"
                $titleCql = [System.Uri]::EscapeDataString("type=page AND title ~ `"$AnchorText`"")
                $searchUrl = "${BaseUrl}/rest/api/content/search?cql=$titleCql&limit=3&expand=_links"
                $sr = Invoke-RestMethod -Uri $searchUrl -Headers $Headers -TimeoutSec 10 -ErrorAction Stop
                if ($sr.results -and $sr.results.Count -gt 0) {
                    $topResult = $sr.results[0]
                    $confluenceLink = "${BaseUrl}$($topResult._links.webui)"
                    Write-Host "[$(Get-Date)] Found Confluence title match: $confluenceLink ($($topResult.title))"
                    return $confluenceLink
                }
            } catch {
                Write-Host "[$(Get-Date)] Confluence title search failed: $($_.Exception.Message)"
            }
        }
    }

    # Strategy 4: Search Confluence using keywords from the broken URL path
    try {
        $uri = [System.Uri]$BrokenUrl
        $pathParts = $uri.AbsolutePath -replace '[/\-_+%20\.]+', ' '
        $pathParts = $pathParts.Trim()
        $pathParts = $pathParts -replace '\b(wiki|pages|spaces|display|html|htm|php|aspx)\b', ''
        $pathParts = ($pathParts -split '\s+' | Where-Object { $_.Length -gt 2 }) -join ' '
        $pathParts = $pathParts.Trim()

        if ($pathParts.Length -gt 2) {
            $cql = [System.Uri]::EscapeDataString("type=page AND text ~ `"$pathParts`"")
            $searchUrl = "${BaseUrl}/rest/api/content/search?cql=$cql&limit=3&expand=_links"
            $sr = Invoke-RestMethod -Uri $searchUrl -Headers $Headers -TimeoutSec 10 -ErrorAction Stop
            if ($sr.results -and $sr.results.Count -gt 0) {
                $topResult = $sr.results[0]
                $confluenceLink = "${BaseUrl}$($topResult._links.webui)"
                Write-Host "[$(Get-Date)] Found Confluence match (URL path): $confluenceLink ($($topResult.title))"
                return $confluenceLink
            }
        }
    } catch {
        Write-Host "[$(Get-Date)] Confluence URL path search failed: $($_.Exception.Message)"
    }

    # Strategy 5: Try Wayback Machine CDX API for archived version
    try {
        $encodedUrl = [System.Uri]::EscapeDataString($BrokenUrl)
        $waybackUrl = "https://archive.org/wayback/available?url=$encodedUrl"
        $waybackResp = Invoke-RestMethod -Uri $waybackUrl -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
        if ($waybackResp.archived_snapshots -and $waybackResp.archived_snapshots.closest -and $waybackResp.archived_snapshots.closest.available -eq $true) {
            $archiveUrl = $waybackResp.archived_snapshots.closest.url
            Write-Host "[$(Get-Date)] Found Wayback Machine archive: $archiveUrl"
            return $archiveUrl
        }
    } catch {
        Write-Host "[$(Get-Date)] Wayback Machine lookup failed: $($_.Exception.Message)"
    }

    Write-Host "[$(Get-Date)] No replacement link found for: $BrokenUrl"
    return $null
}

# --- Helper: Get Destination Page Title ---
function Get-DestinationPageTitle {
    param(
        [string]$Url,
        [hashtable]$Headers,
        [string]$BaseUrl,
        [string]$AnchorText = ""
    )

    # Meaningful anchor text is used as a fallback when the actual title cannot be fetched
    # (broken link, SSO wall, etc.) so the column is never left completely blank.
    $genericAnchors = @('click here','here','link','read more','learn more','this','more',
                        'details','see more','view','page','visit','open','go','source')
    $fallback = if ($AnchorText -and $AnchorText.Length -gt 2 -and
                    $genericAnchors -notcontains $AnchorText.ToLower().Trim()) {
        if ($AnchorText.Length -gt 80) { $AnchorText.Substring(0, 77) + "..." } else { $AnchorText }
    } else { "" }

    # Helper: returns $true when a title string belongs to a login/SSO interstitial page
    $isLoginTitle = {
        param([string]$t)
        $t -match 'SAML|Authentication Required|Authentication Request|Sign[- ]?[Ii]n to|Log[- ]?[Ii]n|Unauthorized|Access Denied|SSO|Single Sign'
    }

    # --- Atlassian / Confluence: use authenticated REST API ---
    if ($Url -match [regex]::Escape($BaseUrl) -or $Url -match 'atlassian\.net') {
        $pageId = $null
        if ($Url -match '/pages/(\d+)')                  { $pageId = $Matches[1] }
        elseif ($Url -match '/spaces/[^/]+/pages/(\d+)') { $pageId = $Matches[1] }
        if (-not $pageId) {
            try { $pageId = Resolve-PageId -Url $Url -Headers $Headers } catch {}
        }
        if ($pageId) {
            try {
                $resp = Invoke-RestMethod -Uri "${BaseUrl}/rest/api/content/${pageId}?expand=title" `
                    -Headers $Headers -TimeoutSec 10 -ErrorAction Stop
                Write-Host "[$(Get-Date)] Title (API): '$($resp.title)' <- $Url"
                return $resp.title
            } catch {
                Write-Host "[$(Get-Date)] Title API failed for $Url : $($_.Exception.Message)"
            }
        }
        # Broken / unresolvable Confluence link -> fall back to anchor text
        Write-Host "[$(Get-Date)] Title fallback (anchor): '$fallback' <- $Url"
        return $fallback
    }

    # --- Hyland internal services (e.g. hyland.udemy.com): try with credentials ---
    # Matches any URL whose host starts with 'hyland.' (e.g. hyland.udemy.com)
    if ($Url -match '//hyland\.') {
        try {
            $resp = Invoke-WebRequest -Uri $Url -Method Get -Headers $Headers `
                -MaximumRedirection 3 -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
            if ($resp.Content -match '<title[^>]*>([^<]+)</title>') {
                $title = [System.Net.WebUtility]::HtmlDecode($Matches[1].Trim())
                if (-not (& $isLoginTitle $title)) {
                    if ($title.Length -gt 80) { $title = $title.Substring(0, 77) + "..." }
                    Write-Host "[$(Get-Date)] Title (web+auth): '$title' <- $Url"
                    return $title
                }
            }
        } catch {}
        # SSO wall - return anchor text so the column is not blank
        Write-Host "[$(Get-Date)] Title fallback (anchor): '$fallback' <- $Url"
        return $fallback
    }

    # --- External URLs: unauthenticated GET ---
    try {
        $resp = Invoke-WebRequest -Uri $Url -Method Get -MaximumRedirection 3 -TimeoutSec 10 `
            -UseBasicParsing -ErrorAction Stop
        if ($resp.Content -match '<title[^>]*>([^<]+)</title>') {
            $title = [System.Net.WebUtility]::HtmlDecode($Matches[1].Trim())
            if (-not (& $isLoginTitle $title)) {
                if ($title.Length -gt 80) { $title = $title.Substring(0, 77) + "..." }
                Write-Host "[$(Get-Date)] Title (web): '$title' <- $Url"
                return $title
            }
        }
    } catch {}

    Write-Host "[$(Get-Date)] Title fallback (anchor): '$fallback' <- $Url"
    return $fallback
}

# --- SCAN Button Click ---
$btnScan.Add_Click({
    # Validate inputs
    if (-not $txtBaseUrl.Text.Trim() -or -not $txtEmail.Text.Trim() -or -not $txtToken.Text.Trim()) {
        [System.Windows.Forms.MessageBox]::Show("Please fill in all credential fields.", "Missing Credentials", "OK", "Warning")
        return
    }
    if (-not $txtPageUrl.Text.Trim()) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a Confluence page URL.", "Missing Page URL", "OK", "Warning")
        return
    }

    $btnScan.Enabled = $false
    $btnPostComment.Enabled = $false
    $btnCreateJira.Enabled = $false
    $btnExport.Enabled = $false
    $dgv.Rows.Clear()
    if ($dgv.Columns.Count -eq 0) {
        $c1 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $c1.Name = "No"; $c1.HeaderText = "#"; $c1.Width = 35; $c1.FillWeight = 6
        $c2 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $c2.Name = "URL"; $c2.HeaderText = "URL"; $c2.FillWeight = 42
        $c6 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $c6.Name = "PageTitle"; $c6.HeaderText = "Destination Page Title"; $c6.FillWeight = 35
        $c3 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $c3.Name = "Status"; $c3.HeaderText = "Status"; $c3.Width = 65; $c3.FillWeight = 9
        $c4 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $c4.Name = "Result"; $c4.HeaderText = "Result"; $c4.FillWeight = 13
        [void]$dgv.Columns.Add($c1)
        [void]$dgv.Columns.Add($c2)
        [void]$dgv.Columns.Add($c6)
        [void]$dgv.Columns.Add($c3)
        [void]$dgv.Columns.Add($c4)
    }
    $lblSummary.Text = ""
    $script:scanResults = @()
    $progressBar.Visible = $true
    $progressBar.Value = 0
    $statusLabel.Text = "Resolving page..."
    $form.Refresh()

    try {
        $headers = Get-AuthHeaders
        $baseUrl = $txtBaseUrl.Text.Trim().TrimEnd('/')

        # Resolve page ID
        $script:pageId = Resolve-PageId -Url $txtPageUrl.Text.Trim() -Headers $headers
        if (-not $script:pageId) {
            throw "Could not resolve page ID from the provided URL."
        }

        $statusLabel.Text = "Fetching page..."
        $form.Refresh()

        # Fetch page content
        $page = Invoke-RestMethod -Uri "${baseUrl}/rest/api/content/$($script:pageId)?expand=body.storage,space" -Headers $headers -ErrorAction Stop
        $script:pageTitle = $page.title
        $htmlBody = $page.body.storage.value

        $statusLabel.Text = "Extracting links..."
        $form.Refresh()

        # Extract links (returns hashtable: href -> anchorText)
        $linkMap = Get-LinksFromHtml -Html $htmlBody

        # Resolve relative links and build ordered list
        $links = @()
        $anchorTextMap = @{}
        foreach ($href in $linkMap.Keys) {
            $resolvedUrl = $null
            if ($href -match '^https?://') {
                $resolvedUrl = $href
            } elseif ($href -match '^/') {
                $uri = [System.Uri]$baseUrl
                $resolvedUrl = "$($uri.Scheme)://$($uri.Host)$href"
            }
            if ($resolvedUrl -and $links -notcontains $resolvedUrl) {
                $links += $resolvedUrl
                $anchorTextMap[$resolvedUrl] = $linkMap[$href]
            }
        }
        if ($links.Count -eq 0) {
            $statusLabel.Text = "No links found"
            $lblSummary.Text = "No external or internal links found on this page."
            $btnScan.Enabled = $true
            $progressBar.Visible = $false
            return
        }

        $progressBar.Maximum = $links.Count
        $statusLabel.Text = "Checking 0/$($links.Count)..."
        $form.Refresh()

        # Check each link
        $counter = 0
        $brokenCount = 0
        foreach ($url in $links) {
            $counter++
            $progressBar.Value = $counter
            $statusLabel.Text = "Checking $counter/$($links.Count)..."
            $form.Refresh()

            $check = Test-LinkHealth -Url $url -AuthHeaders $headers

            # Search for suggested replacement if link is broken
            $suggestedLink = ""
            if ($check.Result -eq "BROKEN") {
                $statusLabel.Text = "Finding fix $counter/$($links.Count)..."
                $form.Refresh()
                $suggestion = Find-SuggestedLink -BrokenUrl $url -AnchorText $anchorTextMap[$url] -Headers $headers -BaseUrl $baseUrl
                if ($suggestion) { $suggestedLink = $suggestion }
            }

            # Fetch the destination page title (falls back to anchor text if unreachable)
            $statusLabel.Text = "Getting title $counter/$($links.Count)..."
            $form.Refresh()
            $pageTitle = Get-DestinationPageTitle -Url $url -Headers $headers -BaseUrl $baseUrl -AnchorText $anchorTextMap[$url]

            $row = $dgv.Rows.Add($counter, $url, $pageTitle, $check.Status, $check.Result)
            if ($check.Result -eq "BROKEN") {
                $dgv.Rows[$row].DefaultCellStyle.ForeColor = $errorColor
                $brokenCount++
            } elseif ($check.Result -eq "Redirect" -or $check.Result -eq "Auth Required") {
                $dgv.Rows[$row].DefaultCellStyle.ForeColor = $warningColor
            } else {
                $dgv.Rows[$row].DefaultCellStyle.ForeColor = $successColor
            }

            $script:scanResults += [PSCustomObject]@{
                No            = $counter
                URL           = $url
                PageTitle     = $pageTitle
                Status        = $check.Status
                Result        = $check.Result
                SuggestedLink = $suggestedLink
            }

            # Rate limit: 500ms between requests
            Start-Sleep -Milliseconds 500
        }

        $okCount = @($script:scanResults | Where-Object { $_.Result -eq "OK" }).Count
        $redirectCount = @($script:scanResults | Where-Object { $_.Result -eq "Redirect" }).Count
        $authRequiredCount = @($script:scanResults | Where-Object { $_.Result -eq "Auth Required" }).Count
        $suggestedCount = @($script:scanResults | Where-Object { $_.SuggestedLink }).Count
        $lblSummary.Text = "Page: $($script:pageTitle)  |  Total: $($links.Count)  |  OK: $okCount  |  Redirects: $redirectCount  |  Auth Required: $authRequiredCount  |  Broken: $brokenCount  |  Suggestions: $suggestedCount"
        $lblSummary.ForeColor = if ($brokenCount -gt 0) { $errorColor } else { $successColor }

        $statusLabel.Text = "Scan complete"
        $btnPostComment.Enabled = ($brokenCount -gt 0 -or $links.Count -gt 0)
        $btnCreateJira.Enabled = ($brokenCount -gt 0)
        $btnExport.Enabled = ($links.Count -gt 0)

    } catch {
        Write-Host "[$(Get-Date)] SCAN ERROR: $($_.Exception.Message)"
        Write-Host "[$(Get-Date)] Stack Trace: $($_.ScriptStackTrace)"
        [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)", "Scan Failed", "OK", "Error")
        $statusLabel.Text = "Error"
    } finally {
        $btnScan.Enabled = $true
        $progressBar.Visible = $false
    }
})

# --- POST COMMENT Button Click ---
$btnPostComment.Add_Click({
    if (-not $script:pageId -or $script:scanResults.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No scan results to post. Run a scan first.", "No Results", "OK", "Warning")
        return
    }

    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Post the scan results as a comment on '$($script:pageTitle)'?",
        "Confirm Post", "YesNo", "Question"
    )
    if ($confirm -ne "Yes") { return }

    $btnPostComment.Enabled = $false
    $statusLabel.Text = "Posting comment..."
    $form.Refresh()

    try {
        $headers = Get-AuthHeaders
        $scanDate = Get-Date -Format "yyyy-MM-dd HH:mm"
        $baseUrl = $txtBaseUrl.Text.Trim().TrimEnd('/')

        $brokenResults = @($script:scanResults | Where-Object { $_.Result -eq "BROKEN" })
        $okCount = @($script:scanResults | Where-Object { $_.Result -eq "OK" }).Count

        # Build HTML table rows
        $tableRows = ""
        foreach ($r in $script:scanResults) {
            $color = if ($r.Result -eq "BROKEN") { "color: red;" } elseif ($r.Result -eq "Redirect") { "color: orange;" } else { "color: green;" }
            $suggestedCell = if ($r.SuggestedLink) { "<a href=`"$($r.SuggestedLink)`">$($r.SuggestedLink)</a>" } else { "-" }
            $pageTitleCell = if ($r.PageTitle) { [System.Net.WebUtility]::HtmlEncode($r.PageTitle) } else { "-" }
            $tableRows += "<tr style=`"$color`"><td>$($r.No)</td><td>$($r.URL)</td><td>$pageTitleCell</td><td>$($r.Status)</td><td>$($r.Result)</td><td>$suggestedCell</td></tr>"
        }

        $htmlComment = "<h3>Broken Link Scan Report</h3>" +
            "<p><strong>Scanned on:</strong> $scanDate</p>" +
            "<p><strong>Page:</strong> $($script:pageTitle)</p>" +
            "<p><strong>Total links checked:</strong> $($script:scanResults.Count) | " +
            "<strong>OK:</strong> $okCount | " +
            "<strong>Broken:</strong> $($brokenResults.Count)</p>" +
            "<table><tr><th>#</th><th>URL</th><th>Destination Page Title</th><th>Status</th><th>Result</th><th>Suggested Replacement</th></tr>" +
            "$tableRows</table>"

        $suggestedResults = @($brokenResults | Where-Object { $_.SuggestedLink })
        if ($brokenResults.Count -gt 0) {
            $htmlComment += "<p><strong>Action Required:</strong> $($brokenResults.Count) broken link(s) need to be fixed or removed.</p>"
            if ($suggestedResults.Count -gt 0) {
                $htmlComment += "<h4>Suggested Replacements</h4><ul>"
                foreach ($s in $suggestedResults) {
                    $htmlComment += "<li><strong>$($s.URL)</strong> &rarr; <a href=`"$($s.SuggestedLink)`">$($s.SuggestedLink)</a></li>"
                }
                $htmlComment += "</ul>"
            }
        } else {
            $htmlComment += "<p><strong>All links are healthy.</strong></p>"
        }

        $payload = @{
            pageId = $script:pageId
            body   = @{
                representation = "storage"
                value          = $htmlComment
            }
        } | ConvertTo-Json -Depth 10

        $r = Invoke-RestMethod -Uri "${baseUrl}/api/v2/footer-comments" -Method Post -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($payload)) -ErrorAction Stop

        [System.Windows.Forms.MessageBox]::Show(
            "Comment posted successfully!`nComment ID: $($r.id)",
            "Success", "OK", "Information"
        )
        $statusLabel.Text = "Comment posted"

    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error posting comment: $($_.Exception.Message)", "Post Failed", "OK", "Error")
        $statusLabel.Text = "Post failed"
    } finally {
        $btnPostComment.Enabled = $true
    }
})

# --- CREATE JIRA TICKETS Button Click ---
$btnCreateJira.Add_Click({
    $brokenResults = @($script:scanResults | Where-Object { $_.Result -eq "BROKEN" })
    if ($brokenResults.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No broken links found. Run a scan first.", "No Broken Links", "OK", "Warning")
        return
    }

    # Prompt for JIRA Project Key
    $projectKeyForm = New-Object System.Windows.Forms.Form
    $projectKeyForm.Text = "JIRA Project Key"
    $projectKeyForm.Size = New-Object System.Drawing.Size(400, 180)
    $projectKeyForm.StartPosition = "CenterParent"
    $projectKeyForm.FormBorderStyle = "FixedDialog"
    $projectKeyForm.MaximizeBox = $false
    $projectKeyForm.MinimizeBox = $false
    $projectKeyForm.BackColor = $bgColor

    $lblProjectKey = New-Object System.Windows.Forms.Label
    $lblProjectKey.Text = "Enter JIRA Project Key (e.g., TRN):"
    $lblProjectKey.Location = New-Object System.Drawing.Point(15, 15)
    $lblProjectKey.Size = New-Object System.Drawing.Size(350, 22)
    $lblProjectKey.Font = New-Object System.Drawing.Font($fontFamily, 9)

    $txtProjectKey = New-Object System.Windows.Forms.TextBox
    $txtProjectKey.Location = New-Object System.Drawing.Point(15, 42)
    $txtProjectKey.Size = New-Object System.Drawing.Size(350, 22)
    $txtProjectKey.Font = New-Object System.Drawing.Font($fontFamily, 10)
    $txtProjectKey.Text = "TRN"

    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Create Tickets"
    $btnOK.Location = New-Object System.Drawing.Point(15, 80)
    $btnOK.Size = New-Object System.Drawing.Size(170, 35)
    $btnOK.BackColor = $warningColor
    $btnOK.ForeColor = [System.Drawing.Color]::White
    $btnOK.FlatStyle = "Flat"
    $btnOK.Font = New-Object System.Drawing.Font($fontFamily, 9, [System.Drawing.FontStyle]::Bold)
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancel"
    $btnCancel.Location = New-Object System.Drawing.Point(195, 80)
    $btnCancel.Size = New-Object System.Drawing.Size(170, 35)
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.Font = New-Object System.Drawing.Font($fontFamily, 9)
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

    $projectKeyForm.Controls.AddRange(@($lblProjectKey, $txtProjectKey, $btnOK, $btnCancel))
    $projectKeyForm.AcceptButton = $btnOK
    $projectKeyForm.CancelButton = $btnCancel

    $dialogResult = $projectKeyForm.ShowDialog()
    $projectKey = $txtProjectKey.Text.Trim().ToUpper()
    $projectKeyForm.Dispose()

    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK -or -not $projectKey) { return }

    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Create $($brokenResults.Count) JIRA story/stories in project '$projectKey' for broken links?`n`nDue date: $((Get-Date).AddDays(3).ToString('yyyy-MM-dd'))",
        "Confirm JIRA Ticket Creation", "YesNo", "Question"
    )
    if ($confirm -ne "Yes") { return }

    $btnCreateJira.Enabled = $false
    $statusLabel.Text = "Creating JIRA tickets..."
    $form.Refresh()

    try {
        $email = $txtEmail.Text.Trim()
        $token = $txtToken.Text.Trim()
        $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${email}:${token}"))
        $jiraBaseUrl = ($txtBaseUrl.Text.Trim() -replace '/wiki.*$', '')
        $headers = @{
            "Authorization" = "Basic $auth"
            "Content-Type"  = "application/json"
            "Accept"        = "application/json"
        }
        $dueDate = (Get-Date).AddDays(3).ToString("yyyy-MM-dd")
        $scanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $pageUrl = $txtPageUrl.Text.Trim()

        $createdTickets = @()
        $failedTickets = @()
        $ticketCount = 0

        foreach ($broken in $brokenResults) {
            $ticketCount++
            $statusLabel.Text = "Creating ticket $ticketCount/$($brokenResults.Count)..."
            $form.Refresh()

            $suggestedText = if ($broken.SuggestedLink) { "Suggested Replacement: $($broken.SuggestedLink)" } else { "No suggested replacement found - manual review required." }
            $actionText = if ($broken.SuggestedLink) { "Action Required: Please update this broken link to the suggested replacement above, or find an alternative." } else { "Action Required: Please update, remove, or replace this broken link." }

            $body = @{
                fields = @{
                    project   = @{ key = $projectKey }
                    summary   = "[Broken Link] $($broken.URL) on Confluence page `"$($script:pageTitle)`""
                    description = @{
                        type    = "doc"
                        version = 1
                        content = @(
                            @{ type = "paragraph"; content = @(@{ type = "text"; text = "A broken link was detected during an automated scan." }) }
                            @{ type = "paragraph"; content = @(@{ type = "text"; text = "Broken URL: $($broken.URL)" }) }
                            @{ type = "paragraph"; content = @(@{ type = "text"; text = "HTTP Status: $($broken.Status)" }) }
                            @{ type = "paragraph"; content = @(@{ type = "text"; text = "Found on: $pageUrl" }) }
                            @{ type = "paragraph"; content = @(@{ type = "text"; text = "Scan Date: $scanDate" }) }
                            @{ type = "paragraph"; content = @(@{ type = "text"; text = $suggestedText; marks = @(@{ type = "strong" }) }) }
                            @{ type = "paragraph"; content = @(@{ type = "text"; text = $actionText }) }
                        )
                    }
                    issuetype = @{ name = "Story" }
                    duedate   = $dueDate
                    labels    = @("broken-link", "automated")
                }
            } | ConvertTo-Json -Depth 10

            try {
                $resp = Invoke-RestMethod -Uri "$jiraBaseUrl/rest/api/3/issue" -Method Post -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -ErrorAction Stop
                $createdTickets += [PSCustomObject]@{
                    URL    = $broken.URL
                    Status = $broken.Status
                    Ticket = $resp.key
                    Link   = "$jiraBaseUrl/browse/$($resp.key)"
                }
            } catch {
                $failedTickets += [PSCustomObject]@{
                    URL   = $broken.URL
                    Error = $_.Exception.Message
                }
            }

            Start-Sleep -Milliseconds 500
        }

        # Show results
        $msg = "JIRA Ticket Creation Complete`n`n"
        $msg += "Created: $($createdTickets.Count) | Failed: $($failedTickets.Count)`n"
        $msg += "Due Date: $dueDate`n`n"

        if ($createdTickets.Count -gt 0) {
            $msg += "Created Tickets:`n"
            foreach ($t in $createdTickets) {
                $msg += "  $($t.Ticket) - $($t.URL)`n"
            }
        }
        if ($failedTickets.Count -gt 0) {
            $msg += "`nFailed:`n"
            foreach ($f in $failedTickets) {
                $msg += "  $($f.URL) - $($f.Error)`n"
            }
        }

        $icon = if ($failedTickets.Count -gt 0) { "Warning" } else { "Information" }
        [System.Windows.Forms.MessageBox]::Show($msg, "JIRA Tickets", "OK", $icon)
        $statusLabel.Text = "$($createdTickets.Count) JIRA ticket(s) created"

    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)", "JIRA Error", "OK", "Error")
        $statusLabel.Text = "JIRA creation failed"
    } finally {
        $btnCreateJira.Enabled = $true
    }
})

# --- EXPORT Button Click ---
$btnExport.Add_Click({
    if ($script:scanResults.Count -eq 0) { return }

    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Filter = "CSV files (*.csv)|*.csv"
    $saveDialog.FileName = "BrokenLinkReport_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"

    if ($saveDialog.ShowDialog() -eq "OK") {
        $script:scanResults | Export-Csv -Path $saveDialog.FileName -NoTypeInformation -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show("Report exported to:`n$($saveDialog.FileName)", "Exported", "OK", "Information")
        $statusLabel.Text = "Exported"
    }
})

# --- Launch ---
Write-Host "[$(Get-Date)] Launching GUI..."
Write-Host "[$(Get-Date)] Base URL: $($txtBaseUrl.Text)"
Write-Host "[$(Get-Date)] Token loaded: $(-not [string]::IsNullOrEmpty($txtToken.Text))"
[void]$form.ShowDialog()
$form.Dispose()
Write-Host "[$(Get-Date)] Script ending."
Stop-Transcript -ErrorAction SilentlyContinue
