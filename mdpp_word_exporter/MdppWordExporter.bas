Attribute VB_Name = "MdppWordExporter"
Option Explicit

' md++ Word Exporter
' Exports a normal Word document to a semantic md++ bundle:
'   root.md
'   root.md.comments.json
'   root.md.import.json
'   themes/word-import.theme.md
'   layouts/word-report.layout.md
'   styles/mdpp-word-base.css
'   assets/*
'
' Import this .bas file into Word VBA, then run ExportActiveDocumentToMdpp.

Private Const MDPP_PROFILE_VERSION As String = "0.15"
Private Const DEFAULT_THEME_FILE As String = "./themes/word-import.theme.md"
Private Const DEFAULT_LAYOUT_FILE As String = "./layouts/word-report.layout.md"
Private Const DEFAULT_STYLESHEET_FILE As String = "./styles/mdpp-word-base.css"

Private mExportStartTime As Single

Public Sub ExportActiveDocumentToMdpp()
    If ActiveDocument Is Nothing Then
        MsgBox "No active document.", vbExclamation
        Exit Sub
    End If

    Dim exportRoot As String
    exportRoot = PickExportFolder()
    If Len(exportRoot) = 0 Then Exit Sub

    ExportActiveDocumentToMdppFolder exportRoot
End Sub

Public Sub ExportActiveDocumentToMdppFolder(ByVal exportRoot As String)
    On Error GoTo Fail

    Dim doc As Document
    Set doc = ActiveDocument
    BeginExportStatus doc.Name

    Dim fso As Object
    ExportStatus "Preparing output folders"
    Set fso = CreateObject("Scripting.FileSystemObject")

    exportRoot = Trim$(exportRoot)
    If Len(exportRoot) = 0 Then Err.Raise vbObjectError + 100, , "Export folder is empty."

    EnsureFolder fso, exportRoot
    EnsureFolder fso, fso.BuildPath(exportRoot, "themes")
    EnsureFolder fso, fso.BuildPath(exportRoot, "layouts")
    EnsureFolder fso, fso.BuildPath(exportRoot, "styles")
    EnsureFolder fso, fso.BuildPath(exportRoot, "assets")
    EnsureFolder fso, fso.BuildPath(exportRoot, "comments")
    ClearGeneratedAssetFiles fso, fso.BuildPath(exportRoot, "assets")

    Dim usedStyles As Object
    Set usedStyles = CreateObject("Scripting.Dictionary")

    Dim generatedStyles As Object
    Set generatedStyles = CreateObject("Scripting.Dictionary")

    Dim diagnostics As Collection
    Set diagnostics = New Collection

    Dim imageFiles As Collection
    Set imageFiles = New Collection
    ExportStatus "Extracting image assets"
    ExtractImagesViaFilteredHtml doc, exportRoot, imageFiles, diagnostics
    YieldToWordUi

    ExportStatus "Collecting Word paragraph styles"
    CollectUsedParagraphStyles doc, usedStyles
    YieldToWordUi

    Dim rootMd As String
    ExportStatus "Building root Markdown"
    rootMd = BuildRootMarkdown(doc, imageFiles, usedStyles, generatedStyles, diagnostics)
    YieldToWordUi

    Dim themeMd As String
    ExportStatus "Building theme"
    themeMd = BuildThemeMarkdown(doc, usedStyles, generatedStyles)
    YieldToWordUi

    Dim layoutMd As String
    ExportStatus "Building layout"
    layoutMd = BuildLayoutMarkdown(doc)
    YieldToWordUi

    Dim css As String
    ExportStatus "Building CSS"
    css = BuildStandardCss(doc, usedStyles, generatedStyles)
    YieldToWordUi

    Dim commentsJson As String
    ExportStatus "Writing comments sidecar"
    commentsJson = BuildCommentsSidecarJson(doc)
    YieldToWordUi

    Dim diagnosticsJson As String
    ExportStatus "Writing diagnostics sidecar"
    diagnosticsJson = BuildImportDiagnosticsJson(doc, diagnostics)
    YieldToWordUi

    ExportStatus "Writing export files"
    WriteUtf8 fso.BuildPath(exportRoot, "root.md"), rootMd
    WriteUtf8 fso.BuildPath(fso.BuildPath(exportRoot, "themes"), "word-import.theme.md"), themeMd
    WriteUtf8 fso.BuildPath(fso.BuildPath(exportRoot, "layouts"), "word-report.layout.md"), layoutMd
    WriteUtf8 fso.BuildPath(fso.BuildPath(exportRoot, "styles"), "mdpp-word-base.css"), css
    WriteUtf8 fso.BuildPath(exportRoot, "root.md.comments.json"), commentsJson
    WriteUtf8 fso.BuildPath(exportRoot, "root.md.import.json"), diagnosticsJson

    ExportStatus "Completed"
    EndExportStatus
    MsgBox "md++ export completed:" & vbCrLf & exportRoot, vbInformation
    Exit Sub

Fail:
    ExportStatus "Failed: " & Err.Description
    EndExportStatus
    MsgBox "md++ export failed: " & Err.Description, vbCritical
End Sub

Private Function PickExportFolder() As String
    On Error GoTo Fail

    Dim dlg As FileDialog
    Set dlg = Application.FileDialog(4) ' msoFileDialogFolderPicker
    dlg.Title = "Choose md++ export folder"
    dlg.AllowMultiSelect = False

    If dlg.Show <> -1 Then
        PickExportFolder = ""
    Else
        PickExportFolder = dlg.SelectedItems(1)
    End If
    Exit Function

Fail:
    PickExportFolder = InputBox("Enter export folder path:", "md++ export")
End Function

Private Sub BeginExportStatus(ByVal sourceName As String)
    mExportStartTime = Timer
    Debug.Print "md++ Word export started: " & sourceName
    ExportStatus "Starting"
End Sub

Private Sub ExportStatus(ByVal message As String)
    On Error Resume Next
    Dim line As String
    line = "md++ export [" & FormatNumberInvariant(ElapsedExportSeconds(), 1) & "s] " & message
    Debug.Print line
    Application.StatusBar = line
    YieldToWordUi
End Sub

Private Sub ExportProgress(ByVal stageName As String, ByVal currentValue As Long, ByVal totalValue As Long, ByVal interval As Long)
    If currentValue <= 0 Then Exit Sub
    If interval <= 0 Then interval = 50
    If currentValue = totalValue Or currentValue Mod interval = 0 Then
        If totalValue > 0 Then
            ExportStatus stageName & " " & CStr(currentValue) & "/" & CStr(totalValue)
        Else
            ExportStatus stageName & " " & CStr(currentValue)
        End If
    End If
End Sub

Private Function ElapsedExportSeconds() As Double
    Dim nowValue As Single
    nowValue = Timer
    If nowValue >= mExportStartTime Then
        ElapsedExportSeconds = nowValue - mExportStartTime
    Else
        ElapsedExportSeconds = (86400# - mExportStartTime) + nowValue
    End If
End Function

Private Sub EndExportStatus()
    On Error Resume Next
    Application.StatusBar = False
End Sub

Private Sub YieldToWordUi()
    On Error Resume Next
    DoEvents
End Sub

Private Sub YieldToWordUiEvery(ByRef counter As Long, ByVal interval As Long)
    counter = counter + 1
    If interval <= 0 Then interval = 50
    If counter Mod interval = 0 Then YieldToWordUi
End Sub

Private Function BuildRootMarkdown(ByVal doc As Document, ByVal imageFiles As Collection, ByVal usedStyles As Object, ByVal generatedStyles As Object, ByVal diagnostics As Collection) As String
    Dim title As String
    title = DocumentTitle(doc)

    Dim sb As String
    sb = "[md:profile]: md++" & vbCrLf
    sb = sb & "[md:profile-version]: " & MDPP_PROFILE_VERSION & vbCrLf
    sb = sb & "[md:title]: <" & MdDirectiveText(title) & ">" & vbCrLf
    sb = sb & "[md:theme]: " & DEFAULT_THEME_FILE & vbCrLf
    sb = sb & "[md:layout]: " & DEFAULT_LAYOUT_FILE & vbCrLf
    sb = sb & "[md:stylesheet]: " & DEFAULT_STYLESHEET_FILE & vbCrLf
    sb = sb & vbCrLf
    sb = sb & "<!-- mdpp-import-source: " & HtmlCommentSafe(doc.Name) & " -->" & vbCrLf
    sb = sb & "<!-- mdpp-sidecar-comments: ./root.md.comments.json -->" & vbCrLf
    sb = sb & "<!-- mdpp-sidecar-diagnostics: ./root.md.import.json -->" & vbCrLf
    sb = sb & vbCrLf

    If doc.Shapes.Count > 0 Then
        Dim shp As Shape
        Dim shapeIndex As Long
        For Each shp In doc.Shapes
            shapeIndex = shapeIndex + 1
            ExportProgress "Scanning floating shapes", shapeIndex, doc.Shapes.Count, 10
            YieldToWordUi
            AddDiagnostic diagnostics, "Floating shape is not placed in source order. Convert important floating shapes to inline pictures before export, or review the assets manually.", "BuildRootMarkdown", "doc.Shapes traversal", ShapeAnchorRange(shp), doc.Name, "shape", ShapeDiagnosticIndex(shp), 0, ""
        Next shp
        sb = sb & "<!-- mdpp-import-warning: floating Word shapes are not placed in source order by this exporter. -->" & vbCrLf & vbCrLf
    End If

    Dim mainRange As Range
    Set mainRange = doc.StoryRanges(wdMainTextStory)

    Dim tables As Tables
    Set tables = mainRange.Tables

    Dim nextTable As Long
    nextTable = 1

    Dim imageIndex As Long
    imageIndex = 1

    Dim inlineShapeCount As Long
    inlineShapeCount = doc.InlineShapes.Count

    If inlineShapeCount > 0 Then
        If imageFiles.Count > inlineShapeCount Then
            AddDiagnostic diagnostics, "Word filtered HTML exported more image files than Word inline image anchors. The exporter emitted every extracted file in export order, grouped across the available inline image anchors.", "BuildRootMarkdown", "map extracted image files to inline anchors", Nothing, doc.Name, "document", "", 0, ""
        End If
    End If

    Dim inlineShapeOrdinal As Long
    inlineShapeOrdinal = 0

    Dim p As Paragraph
    Dim paragraphIndex As Long
    Dim paragraphCount As Long
    Dim paragraphYieldCounter As Long
    paragraphCount = mainRange.Paragraphs.Count
    For Each p In mainRange.Paragraphs
        paragraphIndex = paragraphIndex + 1
        ExportProgress "Building root Markdown paragraphs", paragraphIndex, paragraphCount, 25
        YieldToWordUiEvery paragraphYieldCounter, 10

        Do While nextTable <= tables.Count
            Dim pendingTable As Table
            Set pendingTable = tables(nextTable)

            ' VBA does not short-circuit And, so keep the bounds check separate from table indexing.
            If pendingTable.Range.Start > p.Range.Start Then Exit Do

            ExportStatus "Converting table " & CStr(nextTable) & "/" & CStr(tables.Count)
            sb = sb & TableToMarkdown(doc, pendingTable, diagnostics) & vbCrLf & vbCrLf
            nextTable = nextTable + 1
        Loop

        If Not p.Range.Information(wdWithInTable) Then
            Dim paraMd As String
            paraMd = ParagraphToMarkdown(doc, p, usedStyles, generatedStyles, diagnostics)
            If p.Range.InlineShapes.Count > 0 Then
                If IsImagePlaceholderMarkdown(paraMd) Then paraMd = ""
            End If
            If Len(paraMd) > 0 Then
                sb = sb & paraMd & vbCrLf & vbCrLf
            End If

            Dim ils As InlineShape
            For Each ils In p.Range.InlineShapes
                YieldToWordUi
                inlineShapeOrdinal = inlineShapeOrdinal + 1
                ExportProgress "Emitting inline images", inlineShapeOrdinal, inlineShapeCount, 5

                Dim imagesForAnchor As Long
                imagesForAnchor = ImagesToEmitForAnchor(imageIndex, imageFiles.Count, inlineShapeOrdinal, inlineShapeCount)

                If imagesForAnchor = 0 Then
                    sb = sb & InlineShapeMarkdown(imageIndex, imageFiles, diagnostics, ils.Range, doc.Name) & vbCrLf & vbCrLf
                    imageIndex = imageIndex + 1
                Else
                    Dim imageGroupOffset As Long
                    For imageGroupOffset = 1 To imagesForAnchor
                        sb = sb & InlineShapeMarkdown(imageIndex, imageFiles, diagnostics, ils.Range, doc.Name) & vbCrLf & vbCrLf
                        imageIndex = imageIndex + 1
                    Next imageGroupOffset
                End If
            Next ils
        End If
    Next p

    Do While nextTable <= tables.Count
        YieldToWordUi
        ExportStatus "Converting trailing table " & CStr(nextTable) & "/" & CStr(tables.Count)
        sb = sb & TableToMarkdown(doc, tables(nextTable), diagnostics) & vbCrLf & vbCrLf
        nextTable = nextTable + 1
    Loop

    BuildRootMarkdown = NormalizeLineEndings(sb)
End Function

Private Function ParagraphToMarkdown(ByVal doc As Document, ByVal p As Paragraph, ByVal usedStyles As Object, ByVal generatedStyles As Object, ByVal diagnostics As Collection) As String
    Dim styleName As String
    styleName = StyleNameOfParagraph(p)

    Dim wholeCharacterKey As String
    wholeCharacterKey = WholeRangeCharacterKey(doc, p.Range, styleName)

    Dim wholeCharacterClassAttr As String
    wholeCharacterClassAttr = ClassAttributeForCharacterKey(wholeCharacterKey, usedStyles, generatedStyles, True)

    Dim txt As String
    txt = Trim$(InlineRangeToMarkdown(doc, p.Range, styleName, wholeCharacterKey, diagnostics, "ParagraphToMarkdown", "paragraph inline conversion"))
    If Len(txt) = 0 Then
        ParagraphToMarkdown = ""
        Exit Function
    End If

    Dim defaultParagraphStyle As String
    defaultParagraphStyle = DefaultParagraphStyleName(doc, usedStyles)

    Dim headingLevel As Long
    headingLevel = HeadingLevelOfParagraph(p)

    If headingLevel >= 1 And headingLevel <= 6 Then
        Dim headingClassAttr As String
        headingClassAttr = ClassAttributeForStyle(styleName)
        If IsGenericHeadingStyle(styleName, headingLevel) Then headingClassAttr = ""

        If Len(headingClassAttr) = 0 Then headingClassAttr = AppendClassAttribute(headingClassAttr, FormattingClassForParagraph(doc, p, styleName, generatedStyles))
        headingClassAttr = AppendClassAttribute(headingClassAttr, wholeCharacterClassAttr)

        ParagraphToMarkdown = String$(headingLevel, "#") & " " & txt & InlineAttribute(headingClassAttr)
        Exit Function
    End If

    If IsListParagraph(p) Then
        ParagraphToMarkdown = ListPrefix(p) & txt & InlineAttribute(wholeCharacterClassAttr)
        Exit Function
    End If

    Dim classAttr As String
    If IsDefaultParagraphStyle(styleName, defaultParagraphStyle) Then
        classAttr = FormattingClassForParagraph(doc, p, defaultParagraphStyle, generatedStyles)
    Else
        classAttr = ClassAttributeForStyle(styleName)
    End If
    classAttr = AppendClassAttribute(classAttr, wholeCharacterClassAttr)

    ParagraphToMarkdown = txt & InlineAttribute(classAttr)
End Function

Private Function IsImagePlaceholderMarkdown(ByVal markdownText As String) As Boolean
    Dim s As String
    s = Trim$(markdownText)

    Dim attrPos As Long
    attrPos = InStrRev(s, " {")
    If attrPos > 0 And Right$(s, 1) = "}" Then s = Trim$(Left$(s, attrPos - 1))

    IsImagePlaceholderMarkdown = (s = "/" Or s = "\/")
End Function

Private Function TableToMarkdown(ByVal doc As Document, ByVal tbl As Table, ByVal diagnostics As Collection) As String
    On Error GoTo Fail

    ExportStatus "Reading table at start " & CStr(tbl.Range.Start)

    Dim rowsCount As Long
    Dim colsCount As Long
    rowsCount = tbl.Rows.Count
    colsCount = tbl.Columns.Count

    If rowsCount = 0 Or colsCount = 0 Then
        TableToMarkdown = ""
        Exit Function
    End If

    Dim sb As String
    Dim r As Long, c As Long
    Dim cellYieldCounter As Long

    sb = ""
    For c = 1 To colsCount
        YieldToWordUiEvery cellYieldCounter, 10
        sb = sb & "| " & MarkdownTableCell(CellTextMarkdown(doc, tbl, 1, c, diagnostics)) & " "
    Next c
    sb = sb & "|" & vbCrLf

    For c = 1 To colsCount
        sb = sb & "|---"
    Next c
    sb = sb & "|" & vbCrLf

    If rowsCount >= 2 Then
        For r = 2 To rowsCount
            ExportProgress "Converting table rows", r, rowsCount, 10
            YieldToWordUiEvery cellYieldCounter, 10
            For c = 1 To colsCount
                YieldToWordUiEvery cellYieldCounter, 10
                sb = sb & "| " & MarkdownTableCell(CellTextMarkdown(doc, tbl, r, c, diagnostics)) & " "
            Next c
            sb = sb & "|" & vbCrLf
        Next r
    End If

    TableToMarkdown = sb
    Exit Function

Fail:
    AddDiagnostic diagnostics, "Table could not be converted cleanly; a warning placeholder was emitted.", "TableToMarkdown", "table markdown conversion", tbl.Range, doc.Name, "table", TableDiagnosticIndex(tbl), Err.Number, Err.Description
    TableToMarkdown = "<!-- mdpp-import-warning: table could not be converted cleanly. -->"
End Function

Private Function CellTextMarkdown(ByVal doc As Document, ByVal tbl As Table, ByVal rowIndex As Long, ByVal colIndex As Long, ByVal diagnostics As Collection) As String
    On Error GoTo Fail
    If rowIndex Mod 10 = 0 And colIndex = 1 Then ExportStatus "Reading table row " & CStr(rowIndex)

    Dim cellRange As Range
    Set cellRange = tbl.Cell(rowIndex, colIndex).Range.Duplicate
    StripRangeEndMarks cellRange
    CellTextMarkdown = Trim$(InlineRangeToMarkdown(doc, cellRange, "Normal", "", diagnostics, "CellTextMarkdown", "table cell r" & CStr(rowIndex) & " c" & CStr(colIndex)))
    Exit Function

Fail:
    AddDiagnostic diagnostics, "Table cell could not be read; the exported table cell was left empty.", "CellTextMarkdown", "tbl.Cell(" & CStr(rowIndex) & "," & CStr(colIndex) & ")", tbl.Range, doc.Name, "table-cell", TableDiagnosticIndex(tbl) & " r" & CStr(rowIndex) & " c" & CStr(colIndex), Err.Number, Err.Description
    CellTextMarkdown = ""
End Function

Private Function InlineShapeMarkdown(ByVal imageIndex As Long, ByVal imageFiles As Collection, ByVal diagnostics As Collection, ByVal sourceRange As Range, ByVal sourceName As String) As String
    Dim rel As String
    If imageIndex <= imageFiles.Count Then
        rel = "assets/" & CStr(imageFiles(imageIndex))
    Else
        AddDiagnostic diagnostics, "Inline image " & CStr(imageIndex) & " was not extracted; the Markdown output contains a warning placeholder instead of a broken asset reference.", "InlineShapeMarkdown", "image asset lookup", sourceRange, sourceName, "inline-shape", "image " & CStr(imageIndex), 0, ""
        InlineShapeMarkdown = "<!-- mdpp-import-warning: inline image " & CStr(imageIndex) & " was not extracted. -->"
        Exit Function
    End If

    InlineShapeMarkdown = "![Image " & CStr(imageIndex) & "](" & rel & ")"
End Function

Private Function ImagesToEmitForAnchor(ByVal nextImageIndex As Long, ByVal imageFileCount As Long, ByVal inlineShapeOrdinal As Long, ByVal inlineShapeCount As Long) As Long
    If nextImageIndex > imageFileCount Then
        ImagesToEmitForAnchor = 0
        Exit Function
    End If

    If imageFileCount <= inlineShapeCount Then
        ImagesToEmitForAnchor = 1
        Exit Function
    End If

    Dim remainingImages As Long
    Dim remainingAnchors As Long
    remainingImages = imageFileCount - nextImageIndex + 1
    remainingAnchors = inlineShapeCount - inlineShapeOrdinal + 1

    If remainingAnchors <= 1 Then
        ImagesToEmitForAnchor = remainingImages
    Else
        ImagesToEmitForAnchor = (remainingImages + remainingAnchors - 1) \ remainingAnchors
    End If
End Function

Private Function InlineRangeToMarkdown(ByVal doc As Document, ByVal rng As Range, ByVal baseStyleName As String, ByVal wholeCharacterKey As String, ByVal diagnostics As Collection, ByVal macroProcedure As String, ByVal macroStep As String) As String
    On Error GoTo PlainFallback

    Dim rr As Range
    Set rr = rng.Duplicate
    StripRangeEndMarks rr

    If rr.End <= rr.Start Then
        InlineRangeToMarkdown = ""
        Exit Function
    End If

    If rr.Hyperlinks.Count = 0 Then
        InlineRangeToMarkdown = FormatCharsMarkdown(doc, rr.Start, rr.End, baseStyleName, wholeCharacterKey, diagnostics, rr, macroProcedure, macroStep & " characters")
        Exit Function
    End If

    Dim sb As String
    Dim pos As Long
    pos = rr.Start

    Dim h As Hyperlink
    For Each h In rr.Hyperlinks
        If h.Range.Start > pos Then
            sb = sb & FormatCharsMarkdown(doc, pos, h.Range.Start, baseStyleName, wholeCharacterKey, diagnostics, rr, macroProcedure, macroStep & " before hyperlink")
        End If

        Dim labelText As String
        labelText = CleanRangeText(h.Range.Text)
        If Len(labelText) = 0 Then labelText = h.Address

        Dim target As String
        target = h.Address
        If Len(h.SubAddress) > 0 Then
            If Len(target) > 0 Then
                target = target & "#" & h.SubAddress
            Else
                target = "#" & h.SubAddress
            End If
        End If

        If Len(target) > 0 Then
            sb = sb & "[" & MarkdownEscapeInline(labelText) & "](" & MarkdownEscapeUrl(target) & ")"
        Else
            sb = sb & MarkdownEscapeInline(labelText)
        End If

        pos = h.Range.End
    Next h

    If pos < rr.End Then
        sb = sb & FormatCharsMarkdown(doc, pos, rr.End, baseStyleName, wholeCharacterKey, diagnostics, rr, macroProcedure, macroStep & " after hyperlink")
    End If

    InlineRangeToMarkdown = sb
    Exit Function

PlainFallback:
    AddDiagnostic diagnostics, "Inline range could not be converted with formatting; plain escaped text was emitted.", macroProcedure, macroStep, rng, doc.Name, "range", "", Err.Number, Err.Description
    InlineRangeToMarkdown = MarkdownEscapeInline(CleanRangeText(rng.Text))
End Function

Private Function FormatCharsMarkdown(ByVal doc As Document, ByVal startPos As Long, ByVal endPos As Long, ByVal baseStyleName As String, ByVal wholeCharacterKey As String, ByVal diagnostics As Collection, ByVal sourceRange As Range, ByVal macroProcedure As String, ByVal macroStep As String) As String
    On Error GoTo Fail

    Dim scanCharacterFormatting As Boolean
    scanCharacterFormatting = (Len(wholeCharacterKey) = 0 And RangeMayHaveInlineCharacterFormatting(doc, sourceRange, baseStyleName))
    If scanCharacterFormatting And (endPos - startPos) > 500 Then
        ExportStatus "Scanning inline character formatting in range " & CStr(startPos) & "-" & CStr(endPos)
    End If

    Dim sb As String
    Dim seg As String
    Dim currentBold As Boolean
    Dim currentItalic As Boolean
    Dim currentCharacterKey As String
    Dim characterRunStart As Long
    Dim styleInitialized As Boolean
    Dim initialized As Boolean
    Dim yieldCounter As Long

    Dim i As Long
    For i = startPos To endPos - 1
        YieldToWordUiEvery yieldCounter, 200

        Dim cr As Range
        Set cr = doc.Range(i, i + 1)

        Dim ch As String
        ch = NormalizeWordInlineText(cr.Text)
        If Len(ch) > 0 Then
            Dim isBold As Boolean
            Dim isItalic As Boolean
            Dim characterKey As String
            isBold = (cr.Font.Bold <> 0)
            isItalic = (cr.Font.Italic <> 0)
            If scanCharacterFormatting Then
                characterKey = CharacterFormattingKey(doc, cr, baseStyleName)
            Else
                characterKey = ""
            End If

            If Not initialized Then
                initialized = True
                currentBold = isBold
                currentItalic = isItalic
            End If

            If Not styleInitialized Then
                styleInitialized = True
                currentCharacterKey = characterKey
                characterRunStart = i
            ElseIf characterKey <> currentCharacterKey Then
                AddUnsupportedInlineStyleDiagnostic doc, diagnostics, macroProcedure, macroStep, currentCharacterKey, characterRunStart, i
                currentCharacterKey = characterKey
                characterRunStart = i
            End If

            If isBold <> currentBold Or isItalic <> currentItalic Then
                sb = sb & StyledInlineSegment(seg, currentBold, currentItalic)
                seg = ""
                currentBold = isBold
                currentItalic = isItalic
            End If

            seg = seg & ch
        End If
    Next i

    If styleInitialized Then
        AddUnsupportedInlineStyleDiagnostic doc, diagnostics, macroProcedure, macroStep, currentCharacterKey, characterRunStart, endPos
    End If

    If Len(seg) > 0 Then
        sb = sb & StyledInlineSegment(seg, currentBold, currentItalic)
    End If

    FormatCharsMarkdown = sb
    Exit Function

Fail:
    AddDiagnostic diagnostics, "Character formatting could not be converted; this text segment was omitted.", macroProcedure, macroStep, sourceRange, doc.Name, "range", "start " & CStr(startPos) & " end " & CStr(endPos), Err.Number, Err.Description
    FormatCharsMarkdown = ""
End Function

Private Function StyledInlineSegment(ByVal textValue As String, ByVal isBold As Boolean, ByVal isItalic As Boolean) As String
    Dim escaped As String
    escaped = MarkdownEscapeInline(textValue)

    If Len(Trim$(escaped)) = 0 Then
        StyledInlineSegment = escaped
    ElseIf isBold And isItalic Then
        StyledInlineSegment = "***" & escaped & "***"
    ElseIf isBold Then
        StyledInlineSegment = "**" & escaped & "**"
    ElseIf isItalic Then
        StyledInlineSegment = "*" & escaped & "*"
    Else
        StyledInlineSegment = escaped
    End If
End Function

Private Function BuildThemeMarkdown(ByVal doc As Document, ByVal usedStyles As Object, ByVal generatedStyles As Object) As String
    Dim bodyFont As String
    bodyFont = DefaultBodyFont(doc)

    Dim headingFont As String
    headingFont = StyleFontName(doc, "Heading 1", bodyFont)

    Dim sb As String
    sb = "# Word Import Theme" & vbCrLf & vbCrLf
    sb = sb & "[md:profile]: md++" & vbCrLf
    sb = sb & "[md:profile-version]: " & MDPP_PROFILE_VERSION & vbCrLf
    sb = sb & "[md:title]: <Word Import Theme>" & vbCrLf
    sb = sb & "[md:layout]: ../layouts/word-report.layout.md" & vbCrLf
    sb = sb & "[md:stylesheet]: ../styles/mdpp-word-base.css" & vbCrLf & vbCrLf

    sb = sb & "## colors" & vbCrLf
    sb = sb & "text: #222222" & vbCrLf
    sb = sb & "background: #ffffff" & vbCrLf
    sb = sb & "border: #d0d7de" & vbCrLf
    sb = sb & "muted: #667085" & vbCrLf
    sb = sb & "accent: #204080" & vbCrLf & vbCrLf

    sb = sb & "## fonts" & vbCrLf
    sb = sb & "body: " & ThemeValue(bodyFont & ", sans-serif") & vbCrLf
    sb = sb & "heading: " & ThemeValue(headingFont & ", sans-serif") & vbCrLf
    sb = sb & "code: Consolas, monospace" & vbCrLf & vbCrLf

    sb = sb & "## spacing" & vbCrLf
    sb = sb & "small: 4px" & vbCrLf
    sb = sb & "medium: 12px" & vbCrLf
    sb = sb & "large: 24px" & vbCrLf & vbCrLf

    sb = sb & "## component table" & vbCrLf
    sb = sb & "border: 1px solid {colors.border}" & vbCrLf
    sb = sb & "header-background: #f6f8fa" & vbCrLf
    sb = sb & "cell-padding: 6px 8px" & vbCrLf & vbCrLf

    sb = sb & "## component image" & vbCrLf
    sb = sb & "max-width: 100%" & vbCrLf
    sb = sb & "caption-class: word-caption" & vbCrLf & vbCrLf

    sb = sb & "## component paragraph" & vbCrLf
    sb = sb & ThemePropertiesForStyle(doc, DefaultParagraphStyleName(doc, usedStyles))
    sb = sb & vbCrLf

    sb = sb & "## component heading-1" & vbCrLf
    sb = sb & ThemePropertiesForStyle(doc, "Heading 1")
    sb = sb & vbCrLf

    sb = sb & BuildPageFurnitureTheme(doc)

    Dim keys As Variant
    keys = SortedDictionaryKeys(usedStyles)
    Dim defaultParagraphStyle As String
    defaultParagraphStyle = DefaultParagraphStyleName(doc, usedStyles)

    Dim i As Long
    Dim styleYieldCounter As Long
    For i = LBound(keys) To UBound(keys)
        ExportProgress "Writing theme style classes", i - LBound(keys) + 1, UBound(keys) - LBound(keys) + 1, 25
        YieldToWordUiEvery styleYieldCounter, 50
        Dim styleName As String
        styleName = CStr(keys(i))
        Dim cls As String
        cls = StyleClassName(styleName)
        If Len(cls) > 0 Then
            If ShouldEmitStyleClass(styleName, defaultParagraphStyle) Then
                sb = sb & "## class " & cls & vbCrLf
                sb = sb & ThemePropertiesForStyle(doc, styleName)
                sb = sb & vbCrLf
            End If
        End If
    Next i

    sb = sb & GeneratedThemeClasses(generatedStyles)

    BuildThemeMarkdown = NormalizeLineEndings(sb)
End Function

Private Function BuildPageFurnitureTheme(ByVal doc As Document) As String
    Dim headerText As String
    Dim footerText As String

    On Error Resume Next
    headerText = CleanHeaderFooterText(doc.Sections(1).Headers(wdHeaderFooterPrimary).Range)
    footerText = CleanHeaderFooterText(doc.Sections(1).Footers(wdHeaderFooterPrimary).Range)
    On Error GoTo 0

    If Len(headerText) = 0 And Len(footerText) = 0 Then
        BuildPageFurnitureTheme = ""
        Exit Function
    End If

    Dim sb As String
    sb = "## page-furniture word-report" & vbCrLf
    If Len(headerText) > 0 Then
        sb = sb & "header-center: " & ThemeValue(headerText) & vbCrLf
    End If

    If Len(footerText) > 0 Then
        sb = sb & "footer-center: " & ThemeValue(footerText) & vbCrLf
    End If
    sb = sb & vbCrLf

    BuildPageFurnitureTheme = sb
End Function

Private Function HasPageFurniture(ByVal doc As Document) As Boolean
    Dim headerText As String
    Dim footerText As String

    On Error Resume Next
    headerText = CleanHeaderFooterText(doc.Sections(1).Headers(wdHeaderFooterPrimary).Range)
    footerText = CleanHeaderFooterText(doc.Sections(1).Footers(wdHeaderFooterPrimary).Range)
    On Error GoTo 0

    HasPageFurniture = (Len(headerText) > 0 Or Len(footerText) > 0)
End Function

Private Function BuildLayoutMarkdown(ByVal doc As Document) As String
    Dim ps As PageSetup
    Set ps = doc.PageSetup

    Dim orientationText As String
    If ps.Orientation = wdOrientLandscape Then
        orientationText = "landscape"
    Else
        orientationText = "portrait"
    End If

    Dim canvasText As String
    canvasText = PaperSizeText(ps)

    Dim padTop As String, padRight As String, padBottom As String, padLeft As String
    padTop = PointsToMmText(ps.TopMargin)
    padRight = PointsToMmText(ps.RightMargin)
    padBottom = PointsToMmText(ps.BottomMargin)
    padLeft = PointsToMmText(ps.LeftMargin)

    Dim sb As String
    sb = "# word-report" & vbCrLf & vbCrLf
    sb = sb & "canvas-size: " & canvasText & vbCrLf
    sb = sb & "orientation: " & orientationText & vbCrLf
    sb = sb & "canvas-padding: " & padTop & " " & padRight & " " & padBottom & " " & padLeft & vbCrLf
    sb = sb & "gap: 0" & vbCrLf
    If HasPageFurniture(doc) Then sb = sb & "page-furniture: word-report" & vbCrLf
    sb = sb & vbCrLf
    sb = sb & "|      | 1fr  |" & vbCrLf
    sb = sb & "|------|------|" & vbCrLf
    sb = sb & "| 1fr  | body |" & vbCrLf & vbCrLf
    sb = sb & "body:" & vbCrLf
    sb = sb & "  flow: >body" & vbCrLf

    BuildLayoutMarkdown = sb
End Function

Private Function BuildStandardCss(ByVal doc As Document, ByVal usedStyles As Object, ByVal generatedStyles As Object) As String
    Dim sb As String
    sb = "/* md++ Word import base stylesheet" & vbCrLf
    sb = sb & "   Generated by MdppWordExporter.bas. Safe to edit after export. */" & vbCrLf & vbCrLf

    sb = sb & ".mdpp-document {" & vbCrLf
    sb = sb & "  box-sizing: border-box;" & vbCrLf
    sb = sb & "  color: var(--md-colors-text, #222);" & vbCrLf
    sb = sb & "  background: var(--md-colors-background, #fff);" & vbCrLf
    sb = sb & "  font-family: var(--md-fonts-body, Calibri, Arial, sans-serif);" & vbCrLf
    sb = sb & "  line-height: 1.35;" & vbCrLf
    sb = sb & "}" & vbCrLf & vbCrLf

    sb = sb & ".mdpp-document *, .mdpp-document *::before, .mdpp-document *::after { box-sizing: inherit; }" & vbCrLf & vbCrLf

    sb = sb & ".mdpp-heading {" & vbCrLf
    sb = sb & "  font-family: var(--md-fonts-heading, var(--md-fonts-body, Calibri, Arial, sans-serif));" & vbCrLf
    sb = sb & "  line-height: 1.2;" & vbCrLf
    sb = sb & "  margin: 1.2em 0 0.4em;" & vbCrLf
    sb = sb & "}" & vbCrLf & vbCrLf

    sb = sb & ".mdpp-paragraph { margin: 0 0 0.75em; }" & vbCrLf
    sb = sb & ".mdpp-list { margin: 0 0 0.75em 1.5em; padding-left: 1.2em; }" & vbCrLf
    sb = sb & ".mdpp-blockquote { border-left: 4px solid var(--md-colors-border, #d0d7de); margin: 1em 0; padding-left: 1em; color: var(--md-colors-muted, #667085); }" & vbCrLf & vbCrLf

    sb = sb & "/* Generic Word styles mapped onto semantic md++ elements. */" & vbCrLf
    sb = sb & ".mdpp-document p, .mdpp-paragraph {" & vbCrLf
    sb = sb & CssPropertiesForStyle(doc, DefaultParagraphStyleName(doc, usedStyles))
    sb = sb & "}" & vbCrLf & vbCrLf
    sb = sb & ".mdpp-document h1, .mdpp-heading[data-md-level=""1""] {" & vbCrLf
    sb = sb & CssPropertiesForStyle(doc, "Heading 1")
    sb = sb & "}" & vbCrLf & vbCrLf

    sb = sb & ".mdpp-table {" & vbCrLf
    sb = sb & "  width: 100%;" & vbCrLf
    sb = sb & "  border-collapse: collapse;" & vbCrLf
    sb = sb & "  margin: 1em 0;" & vbCrLf
    sb = sb & "}" & vbCrLf
    sb = sb & ".mdpp-table th, .mdpp-table td, .mdpp-document table th, .mdpp-document table td {" & vbCrLf
    sb = sb & "  border: 1px solid var(--md-colors-border, #d0d7de);" & vbCrLf
    sb = sb & "  padding: 6px 8px;" & vbCrLf
    sb = sb & "  vertical-align: top;" & vbCrLf
    sb = sb & "}" & vbCrLf
    sb = sb & ".mdpp-table th, .mdpp-document table th { background: #f6f8fa; font-weight: 700; }" & vbCrLf & vbCrLf

    sb = sb & ".word-image, .mdpp-image { max-width: 100%; height: auto; }" & vbCrLf & vbCrLf

    sb = sb & ".mdpp-page {" & vbCrLf
    sb = sb & "  position: relative;" & vbCrLf
    sb = sb & "  background: var(--md-colors-background, #fff);" & vbCrLf
    sb = sb & "}" & vbCrLf
    sb = sb & ".mdpp-page-header, .mdpp-page-footer {" & vbCrLf
    sb = sb & "  font-size: 0.85em;" & vbCrLf
    sb = sb & "  color: var(--md-colors-muted, #667085);" & vbCrLf
    sb = sb & "}" & vbCrLf & vbCrLf

    sb = sb & "/* Word style classes generated from the source document. */" & vbCrLf

    Dim keys As Variant
    keys = SortedDictionaryKeys(usedStyles)
    Dim defaultParagraphStyle As String
    defaultParagraphStyle = DefaultParagraphStyleName(doc, usedStyles)

    Dim i As Long
    Dim styleYieldCounter As Long
    For i = LBound(keys) To UBound(keys)
        ExportProgress "Writing CSS style classes", i - LBound(keys) + 1, UBound(keys) - LBound(keys) + 1, 25
        YieldToWordUiEvery styleYieldCounter, 50
        Dim styleName As String
        styleName = CStr(keys(i))
        Dim cls As String
        cls = StyleClassName(styleName)
        If Len(cls) > 0 Then
            If ShouldEmitStyleClass(styleName, defaultParagraphStyle) Then
                sb = sb & "." & CssIdentifier(cls) & " {" & vbCrLf
                sb = sb & CssPropertiesForStyle(doc, styleName)
                sb = sb & "}" & vbCrLf & vbCrLf
            End If
        End If
    Next i

    sb = sb & GeneratedCssClasses(generatedStyles)

    BuildStandardCss = NormalizeLineEndings(sb)
End Function

Private Sub CollectUsedParagraphStyles(ByVal doc As Document, ByVal usedStyles As Object)
    On Error Resume Next

    Dim p As Paragraph
    Dim paragraphIndex As Long
    Dim paragraphCount As Long
    Dim paragraphYieldCounter As Long
    paragraphCount = doc.StoryRanges(wdMainTextStory).Paragraphs.Count
    For Each p In doc.StoryRanges(wdMainTextStory).Paragraphs
        paragraphIndex = paragraphIndex + 1
        ExportProgress "Collecting paragraph styles", paragraphIndex, paragraphCount, 50
        YieldToWordUiEvery paragraphYieldCounter, 20
        If Not p.Range.Information(wdWithInTable) Then
            Dim styleName As String
            styleName = StyleNameOfParagraph(p)
            AddUsedStyle usedStyles, styleName
        End If
    Next p
End Sub

Private Sub AddUsedStyle(ByVal usedStyles As Object, ByVal styleName As String)
    On Error Resume Next
    If Len(styleName) = 0 Then Exit Sub

    If usedStyles.Exists(styleName) Then
        usedStyles(styleName) = CLng(usedStyles(styleName)) + 1
    Else
        usedStyles.Add styleName, 1
    End If
End Sub

Private Function StyleNameOfParagraph(ByVal p As Paragraph) As String
    On Error GoTo Fail
    StyleNameOfParagraph = CStr(p.Style)
    Exit Function
Fail:
    StyleNameOfParagraph = "Normal"
End Function

Private Function HeadingLevelOfParagraph(ByVal p As Paragraph) As Long
    On Error Resume Next

    If p.OutlineLevel >= wdOutlineLevel1 And p.OutlineLevel <= wdOutlineLevel6 Then
        HeadingLevelOfParagraph = p.OutlineLevel
        Exit Function
    End If

    Dim s As String
    s = LCase$(StyleNameOfParagraph(p))
    If Left$(s, 8) = "heading " Then
        HeadingLevelOfParagraph = CLng(Val(Mid$(s, 9)))
    Else
        HeadingLevelOfParagraph = 0
    End If
End Function

Private Function IsListParagraph(ByVal p As Paragraph) As Boolean
    On Error GoTo Fail
    IsListParagraph = (p.Range.ListFormat.ListType <> wdListNoNumbering)
    Exit Function
Fail:
    IsListParagraph = False
End Function

Private Function ListPrefix(ByVal p As Paragraph) As String
    On Error GoTo Fail

    Dim level As Long
    level = p.Range.ListFormat.ListLevelNumber
    If level < 1 Then level = 1

    Dim indent As String
    indent = String$((level - 1) * 2, " ")

    Select Case p.Range.ListFormat.ListType
        Case wdListSimpleNumbering, wdListOutlineNumbering, wdListMixedNumbering, wdListListNumOnly
            ListPrefix = indent & "1. "
        Case Else
            ListPrefix = indent & "- "
    End Select
    Exit Function

Fail:
    ListPrefix = "- "
End Function

Private Function IsDefaultParagraphStyle(ByVal styleName As String, ByVal defaultParagraphStyle As String) As Boolean
    IsDefaultParagraphStyle = (Slugify(styleName) = Slugify(defaultParagraphStyle))
End Function

Private Function IsGenericHeadingStyle(ByVal styleName As String, ByVal headingLevel As Long) As Boolean
    If headingLevel < 1 Or headingLevel > 6 Then
        IsGenericHeadingStyle = False
    Else
        IsGenericHeadingStyle = (Slugify(styleName) = "heading-" & CStr(headingLevel))
    End If
End Function

Private Function ShouldEmitStyleClass(ByVal styleName As String, ByVal defaultParagraphStyle As String) As Boolean
    Dim slug As String
    slug = Slugify(styleName)

    If slug = Slugify(defaultParagraphStyle) Then
        ShouldEmitStyleClass = False
    Else
        ShouldEmitStyleClass = True
        If Left$(slug, 8) = "heading-" Then
            If Len(slug) = 9 Then
                If Mid$(slug, 9, 1) >= "1" Then
                    If Mid$(slug, 9, 1) <= "6" Then ShouldEmitStyleClass = False
                End If
            End If
        End If
    End If
End Function

Private Function DefaultParagraphStyleName(ByVal doc As Document, ByVal usedStyles As Object) As String
    On Error Resume Next
    If Not usedStyles Is Nothing Then
        If usedStyles.Exists("Body Text") And usedStyles.Exists("Normal") Then
            If CLng(usedStyles("Body Text")) > CLng(usedStyles("Normal")) Then
                DefaultParagraphStyleName = "Body Text"
                Exit Function
            End If
        ElseIf usedStyles.Exists("Body Text") Then
            DefaultParagraphStyleName = "Body Text"
            Exit Function
        End If
    End If
    On Error GoTo 0

    DefaultParagraphStyleName = "Normal"
End Function

Private Function ClassAttributeForStyle(ByVal styleName As String) As String
    Dim cls As String
    cls = StyleClassName(styleName)
    If Len(cls) = 0 Then
        ClassAttributeForStyle = ""
    Else
        ClassAttributeForStyle = "." & cls
    End If
End Function

Private Function AppendClassAttribute(ByVal existingClasses As String, ByVal extraClass As String) As String
    If Len(extraClass) = 0 Then
        AppendClassAttribute = existingClasses
    ElseIf Len(existingClasses) = 0 Then
        AppendClassAttribute = extraClass
    Else
        AppendClassAttribute = existingClasses & " " & extraClass
    End If
End Function

Private Function WholeRangeCharacterKey(ByVal doc As Document, ByVal rng As Range, ByVal baseStyleName As String) As String
    On Error GoTo Fail

    Dim rr As Range
    Set rr = rng.Duplicate
    StripRangeEndMarks rr

    If Len(CleanRangeText(rr.Text)) = 0 Then Exit Function

    Dim characterStyleName As String
    characterStyleName = CharacterStyleNameOfRange(rr)
    If Len(characterStyleName) > 0 Then
        WholeRangeCharacterKey = "style:" & characterStyleName
        Exit Function
    End If

    Dim props As String
    props = CharacterFormattingOverridePropertiesStrict(doc, rr, baseStyleName)
    If Len(props) > 0 Then WholeRangeCharacterKey = "props:" & props
    Exit Function

Fail:
    WholeRangeCharacterKey = ""
End Function

Private Function RangeMayHaveInlineCharacterFormatting(ByVal doc As Document, ByVal rng As Range, ByVal baseStyleName As String) As Boolean
    On Error GoTo Fail

    If Len(CharacterStyleNameOfRange(rng)) > 0 Then
        RangeMayHaveInlineCharacterFormatting = True
        Exit Function
    End If

    If Len(CharacterFormattingOverridePropertiesStrict(doc, rng, baseStyleName)) > 0 Then
        RangeMayHaveInlineCharacterFormatting = True
        Exit Function
    End If

    On Error Resume Next
    If rng.Font.Color = wdUndefined Then RangeMayHaveInlineCharacterFormatting = True
    If Len(CStr(rng.Font.Name)) = 0 Then RangeMayHaveInlineCharacterFormatting = True
    If rng.Font.Size = wdUndefined Then RangeMayHaveInlineCharacterFormatting = True
    If rng.Shading.BackgroundPatternColor = wdUndefined Then RangeMayHaveInlineCharacterFormatting = True
    If rng.HighlightColorIndex = wdUndefined Then RangeMayHaveInlineCharacterFormatting = True
    On Error GoTo 0
    Exit Function

Fail:
    RangeMayHaveInlineCharacterFormatting = False
End Function

Private Function CharacterFormattingKey(ByVal doc As Document, ByVal rng As Range, ByVal baseStyleName As String) As String
    Dim characterStyleName As String
    characterStyleName = CharacterStyleNameOfRange(rng)

    If Len(characterStyleName) > 0 Then
        CharacterFormattingKey = "style:" & characterStyleName
        Exit Function
    End If

    Dim props As String
    props = CharacterFormattingOverrideProperties(doc, rng, baseStyleName)
    If Len(props) > 0 Then CharacterFormattingKey = "props:" & props
End Function

Private Function ClassAttributeForCharacterKey(ByVal characterKey As String, ByVal usedStyles As Object, ByVal generatedStyles As Object, ByVal recordClass As Boolean) As String
    Dim cls As String
    cls = CharacterClassNameForKey(characterKey, usedStyles, generatedStyles, recordClass)
    If Len(cls) > 0 Then ClassAttributeForCharacterKey = "." & cls
End Function

Private Function CharacterClassNameForKey(ByVal characterKey As String, ByVal usedStyles As Object, ByVal generatedStyles As Object, ByVal recordClass As Boolean) As String
    If Left$(characterKey, 6) = "style:" Then
        Dim styleName As String
        styleName = Mid$(characterKey, 7)
        If recordClass Then AddUsedStyle usedStyles, styleName
        CharacterClassNameForKey = StyleClassName(styleName)
    ElseIf Left$(characterKey, 6) = "props:" Then
        If recordClass Then CharacterClassNameForKey = GeneratedStyleClassName(generatedStyles, Mid$(characterKey, 7))
    End If
End Function

Private Sub AddUnsupportedInlineStyleDiagnostic(ByVal doc As Document, ByVal diagnostics As Collection, ByVal macroProcedure As String, ByVal macroStep As String, ByVal characterKey As String, ByVal runStart As Long, ByVal runEnd As Long)
    If Len(characterKey) = 0 Or runEnd <= runStart Then Exit Sub

    Dim sourceRange As Range
    Set sourceRange = doc.Range(runStart, runEnd)

    Dim detail As String
    detail = CharacterFormattingDiagnosticLabel(characterKey)

    AddDiagnostic diagnostics, "Character-level " & detail & " was not emitted inline because md++ 0.15 has no portable inline attribute-list syntax. Whole-paragraph character formatting is promoted to a paragraph class instead.", macroProcedure, macroStep & " inline style", sourceRange, doc.Name, "inline-style", "start " & CStr(runStart) & " end " & CStr(runEnd), 0, ""
End Sub

Private Function CharacterFormattingDiagnosticLabel(ByVal characterKey As String) As String
    If Left$(characterKey, 6) = "style:" Then
        CharacterFormattingDiagnosticLabel = "style """ & Mid$(characterKey, 7) & """"
    ElseIf Left$(characterKey, 6) = "props:" Then
        CharacterFormattingDiagnosticLabel = "direct formatting"
    Else
        CharacterFormattingDiagnosticLabel = "formatting"
    End If
End Function

Private Function CharacterStyleNameOfRange(ByVal rng As Range) As String
    On Error GoTo Fail

    Dim st As Style
    Set st = rng.Style

    If st.Type = wdStyleTypeCharacter Then
        Dim styleName As String
        styleName = CStr(st)
        If IsMeaningfulCharacterStyle(styleName) Then CharacterStyleNameOfRange = styleName
    End If
    Exit Function

Fail:
    CharacterStyleNameOfRange = ""
End Function

Private Function IsMeaningfulCharacterStyle(ByVal styleName As String) As Boolean
    Dim slug As String
    slug = Slugify(styleName)
    IsMeaningfulCharacterStyle = (Len(slug) > 0 And slug <> "default-paragraph-font" And slug <> "paragraph-font")
End Function

Private Function CharacterFormattingOverridePropertiesStrict(ByVal doc As Document, ByVal rng As Range, ByVal baseStyleName As String) As String
    Dim sb As String
    Dim actual As String
    Dim base As String

    actual = RangeFontName(rng)
    base = StyleFontName(doc, baseStyleName, "")
    If Len(actual) > 0 Then
        If actual <> base Then sb = sb & CssPropertyLine("font-family", CssString(actual))
    End If

    actual = RangeFontSizeText(rng)
    base = StyleFontSizeText(doc, baseStyleName)
    If Len(actual) > 0 Then
        If actual <> base Then sb = sb & CssPropertyLine("font-size", actual & "pt")
    End If

    actual = RangeFontColorTextNoFallback(rng)
    base = StyleFontColorText(doc, baseStyleName)
    If Len(base) = 0 And actual = "#000000" Then actual = ""
    If Len(actual) > 0 Then
        If actual <> base Then sb = sb & CssPropertyLine("color", actual)
    End If

    actual = RangeBackgroundColorTextNoFallback(rng)
    base = StyleBackgroundColorText(doc, baseStyleName)
    If Len(base) = 0 And actual = "#FFFFFF" Then actual = ""
    If Len(actual) > 0 Then
        If actual <> base Then sb = sb & CssPropertyLine("background-color", actual)
    End If

    CharacterFormattingOverridePropertiesStrict = sb
End Function

Private Function CharacterFormattingOverrideProperties(ByVal doc As Document, ByVal rng As Range, ByVal baseStyleName As String) As String
    Dim sb As String
    Dim actual As String
    Dim base As String

    actual = RangeFontName(rng)
    base = StyleFontName(doc, baseStyleName, "")
    If Len(actual) > 0 Then
        If actual <> base Then sb = sb & CssPropertyLine("font-family", CssString(actual))
    End If

    actual = RangeFontSizeText(rng)
    base = StyleFontSizeText(doc, baseStyleName)
    If Len(actual) > 0 Then
        If actual <> base Then sb = sb & CssPropertyLine("font-size", actual & "pt")
    End If

    actual = RangeFontColorText(rng)
    base = StyleFontColorText(doc, baseStyleName)
    If Len(base) = 0 And actual = "#000000" Then actual = ""
    If Len(actual) > 0 Then
        If actual <> base Then sb = sb & CssPropertyLine("color", actual)
    End If

    actual = RangeBackgroundColorText(rng)
    base = StyleBackgroundColorText(doc, baseStyleName)
    If Len(base) = 0 And actual = "#FFFFFF" Then actual = ""
    If Len(actual) > 0 Then
        If actual <> base Then sb = sb & CssPropertyLine("background-color", actual)
    End If

    CharacterFormattingOverrideProperties = sb
End Function

Private Function FormattingClassForParagraph(ByVal doc As Document, ByVal p As Paragraph, ByVal baseStyleName As String, ByVal generatedStyles As Object) As String
    On Error GoTo Fail

    Dim props As String
    props = ParagraphFormattingOverrideProperties(doc, p.Range, baseStyleName)

    If Len(props) = 0 Then
        FormattingClassForParagraph = ""
    Else
        FormattingClassForParagraph = "." & GeneratedStyleClassName(generatedStyles, props)
    End If
    Exit Function

Fail:
    FormattingClassForParagraph = ""
End Function

Private Function ParagraphFormattingOverrideProperties(ByVal doc As Document, ByVal rng As Range, ByVal baseStyleName As String) As String
    Dim sb As String
    Dim actual As String
    Dim base As String

    actual = RangeAlignmentText(rng)
    base = StyleAlignmentText(doc, baseStyleName)
    If Len(actual) > 0 Then
        If actual <> base Then sb = sb & CssPropertyLine("text-align", actual)
    End If

    ParagraphFormattingOverrideProperties = sb
End Function

Private Function GeneratedStyleClassName(ByVal generatedStyles As Object, ByVal cssProperties As String) As String
    If generatedStyles.Exists(cssProperties) Then
        GeneratedStyleClassName = CStr(generatedStyles(cssProperties))
    Else
        Dim cls As String
        cls = "word-format-" & Format$(generatedStyles.Count + 1, "000")
        generatedStyles.Add cssProperties, cls
        GeneratedStyleClassName = cls
    End If
End Function

Private Function GeneratedThemeClasses(ByVal generatedStyles As Object) As String
    Dim sb As String
    Dim key As Variant

    For Each key In generatedStyles.Keys
        sb = sb & "## class " & CStr(generatedStyles(key)) & vbCrLf
        sb = sb & CssPropertiesToThemeProperties(CStr(key))
        sb = sb & vbCrLf
    Next key

    GeneratedThemeClasses = sb
End Function

Private Function GeneratedCssClasses(ByVal generatedStyles As Object) As String
    Dim sb As String
    Dim key As Variant

    For Each key In generatedStyles.Keys
        sb = sb & "." & CssIdentifier(CStr(generatedStyles(key))) & " {" & vbCrLf
        sb = sb & CStr(key)
        sb = sb & "}" & vbCrLf & vbCrLf
    Next key

    GeneratedCssClasses = sb
End Function

Private Function CssPropertiesToThemeProperties(ByVal cssProperties As String) As String
    Dim props As String
    props = Replace(cssProperties, "  ", "")
    props = Replace(props, ";", "")
    CssPropertiesToThemeProperties = props
End Function

Private Function InlineAttribute(ByVal attrClass As String) As String
    If Len(attrClass) = 0 Then
        InlineAttribute = ""
    Else
        InlineAttribute = " {" & attrClass & "}"
    End If
End Function

Private Function StyleClassName(ByVal styleName As String) As String
    Dim slug As String
    slug = Slugify(styleName)
    If Len(slug) = 0 Then
        StyleClassName = ""
    Else
        StyleClassName = "word-style-" & slug
    End If
End Function

Private Function ThemePropertiesForStyle(ByVal doc As Document, ByVal styleName As String) As String
    Dim props As String
    props = CssPropertiesForStyle(doc, styleName)
    ThemePropertiesForStyle = CssPropertiesToThemeProperties(props)
End Function

Private Function CssPropertiesForStyle(ByVal doc As Document, ByVal styleName As String) As String
    On Error GoTo Fail

    Dim st As Style
    Set st = doc.Styles(styleName)
    On Error Resume Next

    Dim sb As String
    Dim fontName As String
    fontName = st.Font.Name
    If Err.Number <> 0 Then
        Err.Clear
        fontName = ""
    End If
    If Len(fontName) > 0 Then sb = sb & "  font-family: " & CssString(fontName) & ";" & vbCrLf

    If st.Font.Size > 0 And st.Font.Size < 200 Then sb = sb & "  font-size: " & FormatNumberInvariant(st.Font.Size, 1) & "pt;" & vbCrLf
    If Err.Number <> 0 Then Err.Clear
    If st.Font.Bold = True Then sb = sb & "  font-weight: 700;" & vbCrLf
    If Err.Number <> 0 Then Err.Clear
    If st.Font.Italic = True Then sb = sb & "  font-style: italic;" & vbCrLf
    If Err.Number <> 0 Then Err.Clear

    Dim colorValue As String
    colorValue = WordColorToCss(st.Font.Color)
    If Err.Number <> 0 Then
        Err.Clear
        colorValue = ""
    End If
    If Len(colorValue) > 0 Then sb = sb & "  color: " & colorValue & ";" & vbCrLf

    Dim backgroundValue As String
    backgroundValue = StyleBackgroundColorText(doc, styleName)
    If Err.Number <> 0 Then
        Err.Clear
        backgroundValue = ""
    End If
    If Len(backgroundValue) > 0 Then sb = sb & "  background-color: " & backgroundValue & ";" & vbCrLf

    Dim alignValue As String
    alignValue = AlignmentToCss(st.ParagraphFormat.Alignment)
    If Err.Number <> 0 Then
        Err.Clear
        alignValue = ""
    End If
    If Len(alignValue) > 0 Then sb = sb & "  text-align: " & alignValue & ";" & vbCrLf

    If st.ParagraphFormat.SpaceBefore > 0 And st.ParagraphFormat.SpaceBefore < 200 Then sb = sb & "  margin-top: " & FormatNumberInvariant(st.ParagraphFormat.SpaceBefore, 1) & "pt;" & vbCrLf
    If Err.Number <> 0 Then Err.Clear
    If st.ParagraphFormat.SpaceAfter >= 0 And st.ParagraphFormat.SpaceAfter < 200 Then sb = sb & "  margin-bottom: " & FormatNumberInvariant(st.ParagraphFormat.SpaceAfter, 1) & "pt;" & vbCrLf
    If Err.Number <> 0 Then Err.Clear
    On Error GoTo 0

    If Len(sb) = 0 Then sb = "  /* no direct style properties exported */" & vbCrLf
    CssPropertiesForStyle = sb
    Exit Function

Fail:
    CssPropertiesForStyle = "  /* style not accessible in Word object model */" & vbCrLf
End Function

Private Function CssPropertyLine(ByVal propertyName As String, ByVal propertyValue As String) As String
    If Len(propertyValue) = 0 Then
        CssPropertyLine = ""
    Else
        CssPropertyLine = "  " & propertyName & ": " & propertyValue & ";" & vbCrLf
    End If
End Function

Private Function RangeFontName(ByVal rng As Range) As String
    On Error GoTo Fail
    RangeFontName = CStr(rng.Font.Name)
    Exit Function

Fail:
    RangeFontName = ""
End Function

Private Function RangeFontSizeText(ByVal rng As Range) As String
    On Error GoTo Fail
    If rng.Font.Size > 0 And rng.Font.Size < 200 Then RangeFontSizeText = FormatNumberInvariant(rng.Font.Size, 1)
    Exit Function

Fail:
    RangeFontSizeText = ""
End Function

Private Function RangeFontWeightText(ByVal rng As Range) As String
    On Error GoTo Fail
    If rng.Font.Bold = True Then
        RangeFontWeightText = "700"
    ElseIf rng.Font.Bold = False Then
        RangeFontWeightText = "400"
    End If
    Exit Function

Fail:
    RangeFontWeightText = ""
End Function

Private Function RangeFontStyleText(ByVal rng As Range) As String
    On Error GoTo Fail
    If rng.Font.Italic = True Then
        RangeFontStyleText = "italic"
    ElseIf rng.Font.Italic = False Then
        RangeFontStyleText = "normal"
    End If
    Exit Function

Fail:
    RangeFontStyleText = ""
End Function

Private Function RangeFontColorText(ByVal rng As Range) As String
    On Error GoTo Fail
    RangeFontColorText = WordColorToCss(rng.Font.Color)
    If Len(RangeFontColorText) = 0 Then RangeFontColorText = FirstCharacterFontColorText(rng)
    Exit Function

Fail:
    RangeFontColorText = ""
End Function

Private Function RangeFontColorTextNoFallback(ByVal rng As Range) As String
    On Error GoTo Fail
    RangeFontColorTextNoFallback = WordColorToCss(rng.Font.Color)
    Exit Function

Fail:
    RangeFontColorTextNoFallback = ""
End Function

Private Function RangeBackgroundColorText(ByVal rng As Range) As String
    On Error GoTo Fail
    RangeBackgroundColorText = WordColorToCss(rng.Shading.BackgroundPatternColor)
    If Len(RangeBackgroundColorText) = 0 Then RangeBackgroundColorText = WordHighlightColorToCss(rng.HighlightColorIndex)
    If Len(RangeBackgroundColorText) = 0 Then RangeBackgroundColorText = FirstCharacterBackgroundColorText(rng)
    Exit Function

Fail:
    RangeBackgroundColorText = ""
End Function

Private Function RangeBackgroundColorTextNoFallback(ByVal rng As Range) As String
    On Error GoTo Fail
    RangeBackgroundColorTextNoFallback = WordColorToCss(rng.Shading.BackgroundPatternColor)
    If Len(RangeBackgroundColorTextNoFallback) = 0 Then RangeBackgroundColorTextNoFallback = WordHighlightColorToCss(rng.HighlightColorIndex)
    Exit Function

Fail:
    RangeBackgroundColorTextNoFallback = ""
End Function

Private Function FirstCharacterFontColorText(ByVal rng As Range) As String
    On Error GoTo Fail

    Dim i As Long
    For i = rng.Start To rng.End - 1
        Dim cr As Range
        Set cr = rng.Document.Range(i, i + 1)
        If Len(NormalizeWordInlineText(cr.Text)) > 0 Then
            FirstCharacterFontColorText = WordColorToCss(cr.Font.Color)
            If Len(FirstCharacterFontColorText) > 0 Then Exit Function
        End If
    Next i
    Exit Function

Fail:
    FirstCharacterFontColorText = ""
End Function

Private Function FirstCharacterBackgroundColorText(ByVal rng As Range) As String
    On Error GoTo Fail

    Dim i As Long
    For i = rng.Start To rng.End - 1
        Dim cr As Range
        Set cr = rng.Document.Range(i, i + 1)
        If Len(NormalizeWordInlineText(cr.Text)) > 0 Then
            FirstCharacterBackgroundColorText = WordColorToCss(cr.Shading.BackgroundPatternColor)
            If Len(FirstCharacterBackgroundColorText) = 0 Then FirstCharacterBackgroundColorText = WordHighlightColorToCss(cr.HighlightColorIndex)
            If Len(FirstCharacterBackgroundColorText) > 0 Then Exit Function
        End If
    Next i
    Exit Function

Fail:
    FirstCharacterBackgroundColorText = ""
End Function

Private Function RangeAlignmentText(ByVal rng As Range) As String
    On Error GoTo Fail
    RangeAlignmentText = AlignmentToCss(rng.ParagraphFormat.Alignment)
    Exit Function

Fail:
    RangeAlignmentText = ""
End Function

Private Function StyleFontSizeText(ByVal doc As Document, ByVal styleName As String) As String
    On Error GoTo Fail
    If doc.Styles(styleName).Font.Size > 0 And doc.Styles(styleName).Font.Size < 200 Then StyleFontSizeText = FormatNumberInvariant(doc.Styles(styleName).Font.Size, 1)
    Exit Function

Fail:
    StyleFontSizeText = ""
End Function

Private Function StyleFontWeightText(ByVal doc As Document, ByVal styleName As String) As String
    On Error GoTo Fail
    If doc.Styles(styleName).Font.Bold = True Then
        StyleFontWeightText = "700"
    Else
        StyleFontWeightText = "400"
    End If
    Exit Function

Fail:
    StyleFontWeightText = ""
End Function

Private Function StyleFontStyleText(ByVal doc As Document, ByVal styleName As String) As String
    On Error GoTo Fail
    If doc.Styles(styleName).Font.Italic = True Then
        StyleFontStyleText = "italic"
    Else
        StyleFontStyleText = "normal"
    End If
    Exit Function

Fail:
    StyleFontStyleText = ""
End Function

Private Function StyleFontColorText(ByVal doc As Document, ByVal styleName As String) As String
    On Error GoTo Fail
    StyleFontColorText = WordColorToCss(doc.Styles(styleName).Font.Color)
    Exit Function

Fail:
    StyleFontColorText = ""
End Function

Private Function StyleBackgroundColorText(ByVal doc As Document, ByVal styleName As String) As String
    On Error GoTo Fail
    StyleBackgroundColorText = WordColorToCss(doc.Styles(styleName).Shading.BackgroundPatternColor)
    Exit Function

Fail:
    StyleBackgroundColorText = ""
End Function

Private Function StyleAlignmentText(ByVal doc As Document, ByVal styleName As String) As String
    On Error GoTo Fail
    StyleAlignmentText = AlignmentToCss(doc.Styles(styleName).ParagraphFormat.Alignment)
    Exit Function

Fail:
    StyleAlignmentText = ""
End Function

Private Function BuildCommentsSidecarJson(ByVal doc As Document) As String
    Dim sb As String
    sb = "{" & vbCrLf
    sb = sb & "  ""format"": ""mdpp.office-comments.sidecar.v0""," & vbCrLf
    sb = sb & "  ""source"": {" & vbCrLf
    sb = sb & "    ""name"": """ & JsonEscape(doc.Name) & """," & vbCrLf
    sb = sb & "    ""title"": """ & JsonEscape(DocumentTitle(doc)) & """" & vbCrLf
    sb = sb & "  }," & vbCrLf
    sb = sb & "  ""comments"": [" & vbCrLf

    Dim i As Long
    Dim commentYieldCounter As Long
    For i = 1 To doc.Comments.Count
        ExportProgress "Serializing comments", i, doc.Comments.Count, 25
        YieldToWordUiEvery commentYieldCounter, 20
        Dim c As Comment
        Set c = doc.Comments(i)

        If i > 1 Then sb = sb & "," & vbCrLf
        sb = sb & "    {" & vbCrLf
        sb = sb & "      ""id"": " & CStr(i) & "," & vbCrLf
        sb = sb & "      ""author"": """ & JsonEscape(c.Author) & """," & vbCrLf
        sb = sb & "      ""initials"": """ & JsonEscape(c.Initial) & """," & vbCrLf
        sb = sb & "      ""date"": """ & JsonEscape(Format$(c.Date, "yyyy-mm-dd\Thh:nn:ss")) & """," & vbCrLf
        sb = sb & "      ""sourceStart"": " & CStr(c.Scope.Start) & "," & vbCrLf
        sb = sb & "      ""sourceEnd"": " & CStr(c.Scope.End) & "," & vbCrLf
        sb = sb & "      ""scopeText"": """ & JsonEscape(CleanRangeText(c.Scope.Text)) & """," & vbCrLf
        sb = sb & "      ""commentText"": """ & JsonEscape(CleanRangeText(c.Range.Text)) & """" & vbCrLf
        sb = sb & "    }"
    Next i

    sb = sb & vbCrLf & "  ]" & vbCrLf
    sb = sb & "}" & vbCrLf
    BuildCommentsSidecarJson = NormalizeLineEndings(sb)
End Function

Private Function BuildImportDiagnosticsJson(ByVal doc As Document, ByVal diagnostics As Collection) As String
    Dim sb As String
    sb = "{" & vbCrLf
    sb = sb & "  ""format"": ""mdpp.office-import-diagnostics.v0""," & vbCrLf
    sb = sb & "  ""source"": """ & JsonEscape(doc.Name) & """," & vbCrLf
    sb = sb & "  ""diagnostics"": [" & vbCrLf

    Dim i As Long
    For i = 1 To diagnostics.Count
        If i > 1 Then sb = sb & "," & vbCrLf
        If IsObject(diagnostics(i)) Then
            Dim diagnostic As Object
            Set diagnostic = diagnostics(i)
            sb = sb & DiagnosticToJson(diagnostic)
        Else
            sb = sb & LegacyDiagnosticToJson(CStr(diagnostics(i)))
        End If
    Next i

    sb = sb & vbCrLf & "  ]" & vbCrLf
    sb = sb & "}" & vbCrLf
    BuildImportDiagnosticsJson = NormalizeLineEndings(sb)
End Function

Private Sub AddDiagnostic(ByVal diagnostics As Collection, ByVal message As String, ByVal macroProcedure As String, ByVal macroStep As String, ByVal sourceRange As Range, ByVal sourceName As String, ByVal sourceKind As String, ByVal sourceIndex As String, ByVal errorNumber As Long, ByVal errorDescription As String)
    On Error Resume Next

    Dim d As Object
    Set d = CreateObject("Scripting.Dictionary")

    d.Add "severity", "warning"
    d.Add "code", "MDPP0421"
    d.Add "message", message
    d.Add "macroProcedure", macroProcedure
    d.Add "macroStep", macroStep
    d.Add "sourceName", sourceName
    d.Add "sourceKind", sourceKind
    d.Add "sourceIndex", sourceIndex
    d.Add "sourceStart", ""
    d.Add "sourceEnd", ""
    d.Add "sourcePage", ""
    d.Add "sourceLine", ""
    d.Add "sourceText", ""
    d.Add "errorNumber", ""
    d.Add "errorDescription", errorDescription

    If errorNumber <> 0 Then d("errorNumber") = CStr(errorNumber)

    If Not sourceRange Is Nothing Then
        If Len(sourceName) = 0 Then d("sourceName") = sourceRange.Document.Name
        d("sourceStart") = CStr(sourceRange.Start)
        d("sourceEnd") = CStr(sourceRange.End)
        d("sourcePage") = CStr(sourceRange.Information(wdActiveEndPageNumber))
        d("sourceLine") = CStr(sourceRange.Information(wdFirstCharacterLineNumber))
        d("sourceText") = DiagnosticPreview(CleanRangeText(sourceRange.Text), 180)
    End If

    diagnostics.Add d
End Sub

Private Function DiagnosticToJson(ByVal d As Object) As String
    Dim sb As String
    sb = "    {" & vbCrLf
    sb = sb & "      ""severity"": """ & JsonEscape(DiagnosticString(d, "severity", "warning")) & """," & vbCrLf
    sb = sb & "      ""code"": """ & JsonEscape(DiagnosticString(d, "code", "MDPP0421")) & """," & vbCrLf
    sb = sb & "      ""message"": """ & JsonEscape(DiagnosticString(d, "message", "")) & """," & vbCrLf
    sb = sb & "      ""macro"": {" & vbCrLf
    sb = sb & "        ""procedure"": """ & JsonEscape(DiagnosticString(d, "macroProcedure", "")) & """," & vbCrLf
    sb = sb & "        ""step"": """ & JsonEscape(DiagnosticString(d, "macroStep", "")) & """" & vbCrLf
    sb = sb & "      }," & vbCrLf
    sb = sb & "      ""sourceLocation"": {" & vbCrLf
    sb = sb & "        ""name"": """ & JsonEscape(DiagnosticString(d, "sourceName", "")) & """," & vbCrLf
    sb = sb & "        ""kind"": """ & JsonEscape(DiagnosticString(d, "sourceKind", "")) & """," & vbCrLf
    sb = sb & "        ""index"": """ & JsonEscape(DiagnosticString(d, "sourceIndex", "")) & """," & vbCrLf
    sb = sb & "        ""start"": " & DiagnosticNumber(d, "sourceStart") & "," & vbCrLf
    sb = sb & "        ""end"": " & DiagnosticNumber(d, "sourceEnd") & "," & vbCrLf
    sb = sb & "        ""page"": " & DiagnosticNumber(d, "sourcePage") & "," & vbCrLf
    sb = sb & "        ""line"": " & DiagnosticNumber(d, "sourceLine") & "," & vbCrLf
    sb = sb & "        ""text"": """ & JsonEscape(DiagnosticString(d, "sourceText", "")) & """" & vbCrLf
    sb = sb & "      }," & vbCrLf
    sb = sb & "      ""vbaError"": {" & vbCrLf
    sb = sb & "        ""number"": " & DiagnosticNumber(d, "errorNumber") & "," & vbCrLf
    sb = sb & "        ""description"": """ & JsonEscape(DiagnosticString(d, "errorDescription", "")) & """" & vbCrLf
    sb = sb & "      }" & vbCrLf
    sb = sb & "    }"
    DiagnosticToJson = sb
End Function

Private Function LegacyDiagnosticToJson(ByVal message As String) As String
    Dim d As Object
    Set d = CreateObject("Scripting.Dictionary")
    d.Add "severity", "warning"
    d.Add "code", "MDPP0421"
    d.Add "message", message
    d.Add "macroProcedure", ""
    d.Add "macroStep", ""
    d.Add "sourceName", ""
    d.Add "sourceKind", ""
    d.Add "sourceIndex", ""
    d.Add "sourceStart", ""
    d.Add "sourceEnd", ""
    d.Add "sourcePage", ""
    d.Add "sourceLine", ""
    d.Add "sourceText", ""
    d.Add "errorNumber", ""
    d.Add "errorDescription", ""
    LegacyDiagnosticToJson = DiagnosticToJson(d)
End Function

Private Function DiagnosticString(ByVal d As Object, ByVal key As String, ByVal fallback As String) As String
    On Error GoTo Fail
    If d.Exists(key) Then
        DiagnosticString = CStr(d(key))
    Else
        DiagnosticString = fallback
    End If
    Exit Function

Fail:
    DiagnosticString = fallback
End Function

Private Function DiagnosticNumber(ByVal d As Object, ByVal key As String) As String
    Dim s As String
    s = Trim$(DiagnosticString(d, key, ""))
    If Len(s) = 0 Then
        DiagnosticNumber = "null"
    Else
        DiagnosticNumber = s
    End If
End Function

Private Function DiagnosticPreview(ByVal textValue As String, ByVal maxLength As Long) As String
    Dim s As String
    s = SingleLine(textValue)
    If maxLength > 0 And Len(s) > maxLength Then s = Left$(s, maxLength - 1) & "..."
    DiagnosticPreview = s
End Function

Private Function ShapeAnchorRange(ByVal shp As Shape) As Range
    On Error GoTo Fail
    Set ShapeAnchorRange = shp.Anchor
    Exit Function

Fail:
    Set ShapeAnchorRange = Nothing
End Function

Private Function ShapeDiagnosticIndex(ByVal shp As Shape) As String
    On Error GoTo Fail
    ShapeDiagnosticIndex = shp.Name
    Exit Function

Fail:
    ShapeDiagnosticIndex = ""
End Function

Private Function TableDiagnosticIndex(ByVal tbl As Table) As String
    On Error GoTo Fail
    TableDiagnosticIndex = "start " & CStr(tbl.Range.Start) & " end " & CStr(tbl.Range.End)
    Exit Function

Fail:
    TableDiagnosticIndex = ""
End Function

Private Sub ExtractImagesViaFilteredHtml(ByVal doc As Document, ByVal exportRoot As String, ByVal imageFiles As Collection, ByVal diagnostics As Collection)
    On Error GoTo Fail
    Dim stage As String

    stage = "count inline shapes"
    If doc.InlineShapes.Count = 0 Then Exit Sub
    ExportStatus "Extracting images for " & CStr(doc.InlineShapes.Count) & " inline shapes"

    stage = "create filesystem object"
    Dim fso As Object
    Set fso = CreateObject("Scripting.FileSystemObject")

    stage = "create temporary export folder"
    Dim tempRoot As String
    tempRoot = fso.BuildPath(Environ$("TEMP"), "mdpp-word-export-" & Format$(Now, "yyyymmdd-hhnnss") & "-" & CStr(Int(Rnd() * 100000)))
    EnsureFolder fso, tempRoot

    stage = "prepare temporary filtered HTML path"
    Dim tempHtml As String
    tempHtml = fso.BuildPath(tempRoot, "source.html")

    stage = "copy document content to hidden temporary document"
    Dim tmpDoc As Document
    Set tmpDoc = Documents.Add(Visible:=False)
    tmpDoc.Range.FormattedText = doc.Range.FormattedText

    stage = "save temporary document as filtered HTML"
    ExportStatus "Saving temporary filtered HTML for image extraction"
    tmpDoc.SaveAs2 FileName:=tempHtml, FileFormat:=wdFormatFilteredHTML, AddToRecentFiles:=False
    tmpDoc.Close SaveChanges:=False

    stage = "locate filtered HTML image folder"
    Dim filesFolder As String
    filesFolder = fso.BuildPath(tempRoot, "source_files")
    If Not fso.FolderExists(filesFolder) Then
        AddDiagnostic diagnostics, "Word filtered HTML export did not produce an image folder; image references may need manual repair.", "ExtractImagesViaFilteredHtml", stage, Nothing, doc.Name, "document", "", 0, ""
        Exit Sub
    End If

    stage = "collect exported image files"
    Dim arr As Object
    Set arr = CreateObject("System.Collections.ArrayList")

    Dim fileObj As Object
    For Each fileObj In fso.GetFolder(filesFolder).Files
        YieldToWordUi
        If IsImageExtension(fso.GetExtensionName(fileObj.Name)) Then arr.Add fileObj.Path
    Next fileObj
    arr.Sort
    ExportStatus "Found " & CStr(arr.Count) & " extracted image files"

    Dim assetFolder As String
    assetFolder = fso.BuildPath(exportRoot, "assets")

    Dim i As Long
    Dim imageYieldCounter As Long
    For i = 0 To arr.Count - 1
        ExportProgress "Copying image assets", i + 1, arr.Count, 5
        YieldToWordUiEvery imageYieldCounter, 5
        stage = "copy image asset " & CStr(i + 1)
        Dim src As String
        Dim ext As String
        Dim destName As String
        Dim dest As String

        src = CStr(arr(i))
        ext = LCase$(fso.GetExtensionName(src))
        If Len(ext) = 0 Then ext = "png"
        destName = "image-" & Format$(i + 1, "000") & "." & ext
        dest = fso.BuildPath(assetFolder, destName)
        fso.CopyFile src, dest, True
        imageFiles.Add destName
    Next i

    If imageFiles.Count < doc.InlineShapes.Count Then
        AddDiagnostic diagnostics, "Fewer image files were extracted than inline shapes found in the document; later inline images will be emitted as warning placeholders.", "ExtractImagesViaFilteredHtml", "compare extracted image count", Nothing, doc.Name, "document", "", 0, ""
    End If

    stage = "delete temporary export folder"
    On Error Resume Next
    fso.DeleteFolder tempRoot, True
    On Error GoTo 0
    Exit Sub

Fail:
    Dim errNumber As Long
    Dim errDescription As String
    errNumber = Err.Number
    errDescription = Err.Description

    On Error Resume Next
    If Not tmpDoc Is Nothing Then tmpDoc.Close SaveChanges:=False
    If Not fso Is Nothing Then
        If Len(tempRoot) > 0 And fso.FolderExists(tempRoot) Then fso.DeleteFolder tempRoot, True
    End If
    On Error GoTo 0
    AddDiagnostic diagnostics, "Image extraction failed.", "ExtractImagesViaFilteredHtml", stage, Nothing, doc.Name, "document", "", errNumber, errDescription
End Sub

Private Function IsImageExtension(ByVal ext As String) As Boolean
    ext = LCase$(ext)
    Select Case ext
        Case "png", "jpg", "jpeg", "gif", "bmp", "tif", "tiff", "svg", "emf", "wmf"
            IsImageExtension = True
        Case Else
            IsImageExtension = False
    End Select
End Function

Private Function DocumentTitle(ByVal doc As Document) As String
    On Error GoTo Fallback

    Dim t As String
    t = Trim$(CStr(doc.BuiltInDocumentProperties("Title")))
    If Len(t) = 0 Then t = BaseNameWithoutExtension(doc.Name)
    DocumentTitle = t
    Exit Function

Fallback:
    DocumentTitle = BaseNameWithoutExtension(doc.Name)
End Function

Private Function BaseNameWithoutExtension(ByVal fileName As String) As String
    Dim p As Long
    p = InStrRev(fileName, ".")
    If p > 1 Then
        BaseNameWithoutExtension = Left$(fileName, p - 1)
    Else
        BaseNameWithoutExtension = fileName
    End If
End Function

Private Function DefaultBodyFont(ByVal doc As Document) As String
    DefaultBodyFont = StyleFontName(doc, "Normal", "Calibri")
End Function

Private Function StyleFontName(ByVal doc As Document, ByVal styleName As String, ByVal fallback As String) As String
    On Error GoTo Fail
    Dim v As String
    v = doc.Styles(styleName).Font.Name
    If Len(v) = 0 Then v = fallback
    StyleFontName = v
    Exit Function
Fail:
    StyleFontName = fallback
End Function

Private Function PaperSizeText(ByVal ps As PageSetup) As String
    On Error Resume Next

    Select Case ps.PaperSize
        Case wdPaperA4
            PaperSizeText = "A4"
        Case wdPaperLetter
            PaperSizeText = "Letter"
        Case Else
            PaperSizeText = "custom(" & PointsToMmText(ps.PageWidth) & "," & PointsToMmText(ps.PageHeight) & ")"
    End Select
End Function

Private Function PointsToMmText(ByVal pointsValue As Double) As String
    PointsToMmText = FormatNumberInvariant(pointsValue * 25.4 / 72#, 1) & "mm"
End Function

Private Function FormatNumberInvariant(ByVal value As Double, ByVal digits As Long) As String
    Dim s As String
    s = Format$(value, "0" & IIf(digits > 0, "." & String$(digits, "0"), ""))
    FormatNumberInvariant = Replace(s, Application.International(wdDecimalSeparator), ".")
End Function

Private Function WordColorToCss(ByVal colorValue As Long) As String
    On Error GoTo Fail

    If colorValue = wdColorAutomatic Or colorValue = wdUndefined Or colorValue < 0 Then
        WordColorToCss = ""
        Exit Function
    End If

    Dim r As Long, g As Long, b As Long
    r = colorValue Mod 256
    g = (colorValue \ 256) Mod 256
    b = (colorValue \ 65536) Mod 256

    WordColorToCss = "#" & Right$("0" & Hex$(r), 2) & Right$("0" & Hex$(g), 2) & Right$("0" & Hex$(b), 2)
    Exit Function

Fail:
    WordColorToCss = ""
End Function

Private Function WordHighlightColorToCss(ByVal highlightValue As Long) As String
    On Error GoTo Fail

    Select Case highlightValue
        Case wdNoHighlight
            WordHighlightColorToCss = ""
        Case wdYellow
            WordHighlightColorToCss = "#FFFF00"
        Case wdBrightGreen
            WordHighlightColorToCss = "#00FF00"
        Case wdTurquoise
            WordHighlightColorToCss = "#00FFFF"
        Case wdPink
            WordHighlightColorToCss = "#FF00FF"
        Case wdBlue
            WordHighlightColorToCss = "#0000FF"
        Case wdRed
            WordHighlightColorToCss = "#FF0000"
        Case wdDarkBlue
            WordHighlightColorToCss = "#000080"
        Case wdTeal
            WordHighlightColorToCss = "#008080"
        Case wdGreen
            WordHighlightColorToCss = "#008000"
        Case wdViolet
            WordHighlightColorToCss = "#800080"
        Case wdDarkRed
            WordHighlightColorToCss = "#800000"
        Case wdDarkYellow
            WordHighlightColorToCss = "#808000"
        Case wdGray50
            WordHighlightColorToCss = "#808080"
        Case wdGray25
            WordHighlightColorToCss = "#C0C0C0"
        Case wdBlack
            WordHighlightColorToCss = "#000000"
        Case Else
            WordHighlightColorToCss = ""
    End Select
    Exit Function

Fail:
    WordHighlightColorToCss = ""
End Function

Private Function AlignmentToCss(ByVal alignmentValue As Long) As String
    Select Case alignmentValue
        Case wdAlignParagraphCenter
            AlignmentToCss = "center"
        Case wdAlignParagraphRight
            AlignmentToCss = "right"
        Case wdAlignParagraphJustify, wdAlignParagraphJustifyHi, wdAlignParagraphJustifyLow, wdAlignParagraphJustifyMed
            AlignmentToCss = "justify"
        Case wdAlignParagraphLeft
            AlignmentToCss = "left"
        Case Else
            AlignmentToCss = ""
    End Select
End Function

Private Function CleanHeaderFooterText(ByVal rng As Range) As String
    CleanHeaderFooterText = SingleLine(CleanRangeText(rng.Text))
End Function

Private Function CleanRangeText(ByVal textValue As String) As String
    Dim s As String
    s = NormalizeWordInlineText(textValue)
    s = Trim$(s)
    CleanRangeText = s
End Function

Private Function SingleLine(ByVal textValue As String) As String
    Dim s As String
    s = Replace(textValue, vbCrLf, " ")
    s = Replace(s, vbCr, " ")
    s = Replace(s, vbLf, " ")
    Do While InStr(s, "  ") > 0
        s = Replace(s, "  ", " ")
    Loop
    SingleLine = Trim$(s)
End Function

Private Sub StripRangeEndMarks(ByVal rng As Range)
    On Error Resume Next
    Do While rng.End > rng.Start
        Dim lastChar As String
        lastChar = rng.Document.Range(rng.End - 1, rng.End).Text
        If IsWordRangeEndMark(lastChar) Then
            rng.End = rng.End - 1
        Else
            Exit Do
        End If
    Loop
End Sub

Private Function IsWordRangeEndMark(ByVal textValue As String) As Boolean
    Select Case textValue
        Case Chr$(13), Chr$(7), Chr$(11), Chr$(12), Chr$(13) & Chr$(7)
            IsWordRangeEndMark = True
        Case Else
            IsWordRangeEndMark = False
    End Select
End Function

Private Function NormalizeWordInlineText(ByVal textValue As String) As String
    Dim s As String
    s = textValue
    s = Replace(s, Chr$(13) & Chr$(7), "")
    s = Replace(s, Chr$(7), "")
    s = Replace(s, Chr$(12), "")
    s = Replace(s, Chr$(11), vbLf)
    s = Replace(s, Chr$(13), vbLf)
    s = Replace(s, vbTab, " ")
    NormalizeWordInlineText = s
End Function

Private Function MarkdownEscapeInline(ByVal textValue As String) As String
    Dim s As String
    s = textValue
    s = Replace(s, "\", "\\")
    s = Replace(s, "`", "\`")
    s = Replace(s, "*", "\*")
    s = Replace(s, "_", "\_")
    s = Replace(s, "[", "\[")
    s = Replace(s, "]", "\]")
    MarkdownEscapeInline = s
End Function

Private Function MarkdownTableCell(ByVal textValue As String) As String
    Dim s As String
    s = NormalizeWordInlineText(textValue)
    s = Replace(s, vbCrLf, " <br> ")
    s = Replace(s, vbCr, " <br> ")
    s = Replace(s, vbLf, " <br> ")
    s = Replace(s, "|", "\|")
    MarkdownTableCell = s
End Function

Private Function MarkdownEscapeUrl(ByVal textValue As String) As String
    Dim s As String
    s = textValue
    s = Replace(s, " ", "%20")
    s = Replace(s, ")", "%29")
    MarkdownEscapeUrl = s
End Function

Private Function MdDirectiveText(ByVal textValue As String) As String
    Dim s As String
    s = Replace(textValue, "<", "")
    s = Replace(s, ">", "")
    s = Replace(s, vbCr, " ")
    s = Replace(s, vbLf, " ")
    MdDirectiveText = Trim$(s)
End Function

Private Function ThemeValue(ByVal textValue As String) As String
    Dim s As String
    s = SingleLine(textValue)
    s = Replace(s, "{", "\{")
    s = Replace(s, "}", "\}")
    ThemeValue = s
End Function

Private Function CssString(ByVal textValue As String) As String
    Dim s As String
    s = Replace(textValue, "\", "\\")
    s = Replace(s, """", "\""")
    CssString = """" & s & """"
End Function

Private Function CssIdentifier(ByVal textValue As String) As String
    CssIdentifier = Replace(textValue, ".", "\.")
End Function

Private Function JsonEscape(ByVal textValue As String) As String
    Dim s As String
    s = textValue
    s = Replace(s, "\", "\\")
    s = Replace(s, """", "\""")
    s = Replace(s, vbCrLf, "\n")
    s = Replace(s, vbCr, "\n")
    s = Replace(s, vbLf, "\n")
    s = Replace(s, vbTab, "\t")
    JsonEscape = s
End Function

Private Function HtmlCommentSafe(ByVal textValue As String) As String
    HtmlCommentSafe = Replace(textValue, "--", "- -")
End Function

Private Function Slugify(ByVal textValue As String) As String
    Dim s As String
    s = LCase$(Trim$(textValue))

    Dim i As Long
    Dim out As String
    For i = 1 To Len(s)
        Dim ch As String
        ch = Mid$(s, i, 1)
        If (ch >= "a" And ch <= "z") Or (ch >= "0" And ch <= "9") Then
            out = out & ch
        ElseIf ch = " " Or ch = "_" Or ch = "-" Or ch = "." Or ch = "/" Or ch = "\" Or ch = ":" Then
            If Len(out) > 0 And Right$(out, 1) <> "-" Then out = out & "-"
        End If
    Next i

    Do While Right$(out, 1) = "-"
        out = Left$(out, Len(out) - 1)
    Loop

    If Len(out) = 0 Then out = "style"
    Slugify = out
End Function

Private Function SortedDictionaryKeys(ByVal dict As Object) As Variant
    Dim arr As Object
    Set arr = CreateObject("System.Collections.ArrayList")

    Dim k As Variant
    For Each k In dict.Keys
        arr.Add CStr(k)
    Next k
    arr.Sort

    If arr.Count = 0 Then
        Dim emptyArr(0 To 0) As String
        emptyArr(0) = "Normal"
        SortedDictionaryKeys = emptyArr
        Exit Function
    End If

    Dim result() As String
    ReDim result(0 To arr.Count - 1)

    Dim i As Long
    For i = 0 To arr.Count - 1
        result(i) = CStr(arr(i))
    Next i

    SortedDictionaryKeys = result
End Function

Private Function NormalizeLineEndings(ByVal textValue As String) As String
    Dim s As String
    s = Replace(textValue, vbCrLf, vbLf)
    s = Replace(s, vbCr, vbLf)
    s = Replace(s, vbLf, vbCrLf)
    NormalizeLineEndings = s
End Function

Private Sub EnsureFolder(ByVal fso As Object, ByVal folderPath As String)
    If Len(folderPath) = 0 Then Exit Sub
    If Not fso.FolderExists(folderPath) Then fso.CreateFolder folderPath
End Sub

Private Sub ClearGeneratedAssetFiles(ByVal fso As Object, ByVal folderPath As String)
    On Error Resume Next
    If Len(folderPath) = 0 Then Exit Sub
    If Not fso.FolderExists(folderPath) Then Exit Sub

    Dim fileObj As Object
    For Each fileObj In fso.GetFolder(folderPath).Files
        If LCase$(Left$(fileObj.Name, 6)) = "image-" Then fso.DeleteFile fileObj.Path, True
    Next fileObj
End Sub

Private Sub WriteUtf8(ByVal filePath As String, ByVal content As String)
    Dim stream As Object
    Set stream = CreateObject("ADODB.Stream")
    stream.Type = 2
    stream.Charset = "utf-8"
    stream.Open
    stream.WriteText content
    stream.SaveToFile filePath, 2
    stream.Close
End Sub
