#!/usr/bin/env python3
import json, os, re, sys, textwrap
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
fmt = payload.get('format', 'docx').lower().lstrip('.')
title = payload.get('title') or 'Новый документ'
subtitle = payload.get('subtitle') or ''
content = payload.get('content') or ''
sections = payload.get('sections') or []
slides = payload.get('slides') or []
outdir = Path.home() / 'Documents' / 'JARVIS'
outdir.mkdir(parents=True, exist_ok=True)
base = re.sub(r'[\\/:*?"<>|]+', '-', title).strip(' .') or 'Новый документ'
base = re.sub(r'\s+', ' ', base)[:90]
ext = fmt if fmt in {'pptx','docx','pdf','txt','md','rtf'} else 'txt'
out = outdir / f'{base}.{ext}'
i = 2
while out.exists():
    out = outdir / f'{base} ({i}).{ext}'; i += 1

if fmt == 'pptx':
    from pptx import Presentation
    from pptx.util import Inches, Pt
    from pptx.dml.color import RGBColor
    from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
    from pptx.enum.shapes import MSO_SHAPE
    prs = Presentation(); prs.slide_width = Inches(13.333); prs.slide_height = Inches(7.5)
    blank = prs.slide_layouts[6]
    ink = RGBColor(8, 13, 17); lime = RGBColor(198, 255, 0); white = RGBColor(244, 247, 242); muted = RGBColor(157, 173, 166)
    def textbox(slide, x, y, w, h, text, size, color, bold=False, font='Aptos'):
        shape = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
        tf = shape.text_frame; tf.clear(); tf.word_wrap = True
        tf.margin_left = Inches(.02); tf.margin_right = Inches(.02); tf.margin_top = Inches(.02); tf.margin_bottom = Inches(.02)
        p = tf.paragraphs[0]; p.text = str(text); p.font.name = font; p.font.size = Pt(size); p.font.bold = bold; p.font.color.rgb = color
        return shape
    def base_slide(kicker, num):
        s = prs.slides.add_slide(blank); s.background.fill.solid(); s.background.fill.fore_color.rgb = ink
        bar = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, Inches(.12), prs.slide_height); bar.fill.solid(); bar.fill.fore_color.rgb = lime; bar.line.fill.background()
        textbox(s, .65, .36, 9, .3, kicker.upper(), 10, lime, True)
        textbox(s, 12.0, .36, .7, .3, f'{num:02d}', 10, muted, True)
        line = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(.65), Inches(7.08), Inches(12.0), Inches(.012)); line.fill.solid(); line.fill.fore_color.rgb = RGBColor(47,61,58); line.line.fill.background()
        textbox(s, .65, 7.12, 9, .2, 'JARVIS  /  PRESENTATION', 8, muted, True)
        return s
    s = prs.slides.add_slide(blank); s.background.fill.solid(); s.background.fill.fore_color.rgb = ink
    accent = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, Inches(.16), prs.slide_height); accent.fill.solid(); accent.fill.fore_color.rgb = lime; accent.line.fill.background()
    # oversized title and restrained accent geometry
    circle = s.shapes.add_shape(MSO_SHAPE.OVAL, Inches(9.35), Inches(1.0), Inches(3.1), Inches(3.1)); circle.fill.background(); circle.line.color.rgb = RGBColor(48,75,61); circle.line.width = Pt(1.4)
    textbox(s, .95, 1.2, 8.3, 2.5, title, 34, white, True)
    if subtitle: textbox(s, .98, 4.0, 7.5, 1.0, subtitle, 17, muted)
    textbox(s, .98, 6.55, 7.5, .35, 'JARVIS  •  STRATEGIC BRIEF', 10, lime, True)
    all_slides = slides or [{'title':'Ключевые выводы','bullets':[content[:700] or 'Основные положения и выводы'] }]
    for idx, item in enumerate(all_slides, 2):
        s = base_slide('ИССЛЕДОВАНИЕ  /  ОСНОВНЫЕ ТЕЗИСЫ', idx)
        textbox(s, .72, .95, 11.7, .9, item.get('title','Раздел'), 27, white, True)
        sub = item.get('subtitle','')
        if sub: textbox(s, .75, 1.85, 11.5, .5, sub, 13, muted)
        bullets = item.get('bullets') or ([item.get('body','')] if item.get('body') else [])
        y = 2.35 if sub else 2.0
        for j, bullet in enumerate(bullets[:5]):
            marker = s.shapes.add_shape(MSO_SHAPE.OVAL, Inches(.82), Inches(y+.12), Inches(.12), Inches(.12)); marker.fill.solid(); marker.fill.fore_color.rgb = lime; marker.line.fill.background()
            textbox(s, 1.15, y, 10.8, .72, bullet, 17, white)
            y += 0.86
    prs.save(out)
elif fmt == 'docx':
    from docx import Document
    from docx.shared import Inches, Pt, RGBColor
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    d=Document(); sec=d.sections[0]; sec.top_margin=Inches(.8); sec.bottom_margin=Inches(.8); sec.left_margin=Inches(.95); sec.right_margin=Inches(.85)
    normal=d.styles['Normal']; normal.font.name='Aptos'; normal.font.size=Pt(11); normal.font.color.rgb=RGBColor(40,48,48)
    for name,size in [('Title',28),('Heading 1',19),('Heading 2',14)]:
        st=d.styles[name]; st.font.name='Aptos Display'; st.font.size=Pt(size); st.font.bold=True; st.font.color.rgb=RGBColor(34,68,54)
    p=d.add_paragraph(); p.style='Title'; p.add_run(title)
    if subtitle:
        p=d.add_paragraph(subtitle); p.runs[0].italic=True
    if content:
        for para in content.split('\n\n'): d.add_paragraph(para)
    for secdata in sections:
        d.add_heading(secdata.get('heading','Раздел'), level=1)
        body=secdata.get('body','')
        for para in body.split('\n\n'):
            if para.strip(): d.add_paragraph(para)
        for bullet in secdata.get('bullets',[]): d.add_paragraph(bullet, style='List Bullet')
    d.save(out)
elif fmt == 'pdf':
    from reportlab.lib.pagesizes import A4
    from reportlab.lib import colors
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.enums import TA_LEFT
    from reportlab.lib.units import mm
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, ListFlowable, ListItem
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    font='/System/Library/Fonts/Supplemental/Arial.ttf'
    bold='/System/Library/Fonts/Supplemental/Arial Bold.ttf'
    if os.path.exists(font): pdfmetrics.registerFont(TTFont('JArial',font)); pdfmetrics.registerFont(TTFont('JArialBold',bold if os.path.exists(bold) else font)); base='JArial'; bfont='JArialBold'
    else: base='Helvetica'; bfont='Helvetica-Bold'
    doc=SimpleDocTemplate(str(out),pagesize=A4,rightMargin=22*mm,leftMargin=22*mm,topMargin=22*mm,bottomMargin=20*mm)
    styles=getSampleStyleSheet(); styles.add(ParagraphStyle(name='JTitle',parent=styles['Title'],fontName=bfont,fontSize=25,leading=31,textColor=colors.HexColor('#173C30'),alignment=TA_LEFT,spaceAfter=14)); styles.add(ParagraphStyle(name='JSub',fontName=base,fontSize=11,leading=16,textColor=colors.HexColor('#64736D'),spaceAfter=22)); styles.add(ParagraphStyle(name='JHead',fontName=bfont,fontSize=16,leading=21,textColor=colors.HexColor('#245A43'),spaceBefore=16,spaceAfter=8)); styles.add(ParagraphStyle(name='JBody',fontName=base,fontSize=10.5,leading=16,textColor=colors.HexColor('#26332E'),spaceAfter=9))
    story=[Paragraph(title,styles['JTitle'])]
    if subtitle: story.append(Paragraph(subtitle,styles['JSub']))
    for para in content.split('\n\n'):
        if para.strip(): story.append(Paragraph(para.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;').replace('\n','<br/>'),styles['JBody']))
    for secdata in sections:
        story.append(Paragraph(secdata.get('heading','Раздел'),styles['JHead']))
        for para in secdata.get('body','').split('\n\n'):
            if para.strip(): story.append(Paragraph(para.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;').replace('\n','<br/>'),styles['JBody']))
        for bullet in secdata.get('bullets',[]): story.append(Paragraph('• '+bullet.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;'),styles['JBody']))
    def footer(canvas,doc):
        canvas.saveState(); canvas.setStrokeColor(colors.HexColor('#DCE6DF')); canvas.line(22*mm,14*mm,188*mm,14*mm); canvas.setFont(base,8); canvas.setFillColor(colors.HexColor('#819087')); canvas.drawString(22*mm,9*mm,'JARVIS  •  DOCUMENT'); canvas.drawRightString(188*mm,9*mm,str(doc.page)); canvas.restoreState()
    doc.build(story,onFirstPage=footer,onLaterPages=footer)
elif fmt in ('txt','md','rtf'):
    body = f'# {title}\n\n' if fmt=='md' else (title+'\n'+'='*len(title)+'\n\n' if fmt=='txt' else '')
    if subtitle: body += subtitle+'\n\n'
    if content: body += content+'\n\n'
    for secdata in sections:
        h=secdata.get('heading','Раздел'); body += (f'## {h}\n\n' if fmt=='md' else h+'\n'+'-'*len(h)+'\n\n')
        body += secdata.get('body','')+'\n\n'
        for bullet in secdata.get('bullets',[]): body += ('- ' if fmt=='md' else '• ')+bullet+'\n'
    if fmt=='rtf':
        esc=body.replace('\\','\\\\').replace('{','\\{').replace('}','\\}').replace('\n','\\par\n')
        out.write_text('{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0 Arial;}}\\f0\\fs22 '+esc+'}',encoding='utf-8')
    else: out.write_text(body,encoding='utf-8')
else:
    out.write_text('',encoding='utf-8')
print(json.dumps({'path':str(out),'format':ext,'bytes':out.stat().st_size},ensure_ascii=False))