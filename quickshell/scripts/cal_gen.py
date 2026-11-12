#!/usr/bin/env python3
import calendar
import datetime
import locale

for loc in ('fr_FR.UTF-8', 'fr_FR.utf8', ''):
    try:
        locale.setlocale(locale.LC_TIME, loc)
        break
    except Exception:
        pass

now = datetime.date.today()
cal = calendar.TextCalendar(calendar.MONDAY)
lines = cal.formatmonth(now.year, now.month).splitlines()

out = f" {now.strftime('%A %d/%m')}<br><br><tt>"
out += f"<span style='color:#e5e5e5;'><b>{lines[0].center(20).replace(' ', '&nbsp;')}</b></span><br>"
out += f"<span style='color:#ff8800;'><b>{lines[1].replace(' ', '&nbsp;')}</b></span><br>"

for week in cal.monthdayscalendar(now.year, now.month):
    cells = []
    for day in week:
        if day == 0:
            cells.append("&nbsp;&nbsp;")
        elif day == now.day:
            s = f"{day:2d}".replace(" ", "&nbsp;")
            cells.append(f"<span style='color:#ff8800;'><b><u>{s}</u></b></span>")
        else:
            s = f"{day:2d}".replace(" ", "&nbsp;")
            cells.append(f"<span style='color:#cccccc;'><b>{s}</b></span>")
    out += "&nbsp;".join(cells) + "<br>"

out += "</tt>"
print(out)
