# Diq UI components

ซอร์ส UI อยู่ใน `ui/` ส่วน `DiqUILib.lua` ที่ root เป็นไฟล์ generated สำหรับ loader เดิม
แก้ไฟล์ใน `ui/` แล้ว build เสมอ อย่าแก้ generated file โดยตรง
ยังคืนตาราง UI และรองรับ `CreateWindow`, `CreateTab`, `CreateToggle`, `Notify`, `LoadIcons`,
`SetTheme`, `Destroy` รวมถึงรูปแบบ dot/colon และค่า return ของ controls ตามเดิม
ไม่มี dependency เพิ่ม ไม่มี Studio ModuleScript และไม่ใช้ filesystem API ของ executor

## เลือกไฟล์ที่จะแก้

| ส่วน | ไฟล์/โฟลเดอร์ | ความรับผิดชอบ |
|---|---|---|
| Public API | `ui/init.lua` | ส่ง options/Runtime เข้า UI, เก็บหน้าต่างปัจจุบัน, rollback เมื่อสร้างไม่สำเร็จ |
| สี | `ui/core/Theme.lua` | theme แยกต่อ UI instance, whitelist ของ `SetTheme` |
| รูปแบบร่วม | `ui/core/Tokens.lua` | ฟอนต์ ขนาดข้อความ มุมโค้ง และระยะห่างหลัก |
| Cleanup | `ui/core/Lifecycle.lua` | tracker, งาน callback ที่ yield, reset registration และ setters หลัง Destroy |
| Input | `ui/core/Input.lua` | รับ input ผ่าน Runtime เมื่อมี, dispatcher สำหรับ slider และการลากหน้าต่าง |
| GUI helpers | `ui/core/Primitives.lua` | Tween, corner, stroke, padding, section styling และ icons |
| Layout | `ui/layout/Window.lua`, `Tab.lua`, `Section.lua` | หน้าต่าง การสลับแท็บ และ ownership ของ containers |
| API adapter | `ui/layout/Container.lua` | แปลง `tab:Create*` / `section:Create*` ไปเป็น constructor ของ component |
| Controls | `ui/components/` | Button, Label, Toggle, Slider, Dropdown, Input, Keybind, Hotkey |
| ชุด controls | `ui/blocks/SettingRow.lua` | ประกอบ Toggle + Hotkey + Slider โดยใช้ slider implementation เดียว |
| การ์ด | `ui/blocks/ProfileCard.lua` | แสดงโปรไฟล์ ชื่อเกม และเวลา session พร้อมงานที่ยกเลิกได้ |
| แจ้งเตือน | `ui/overlays/Notification.lua` | GUI และ timer ของ notifications |

หน้าตาเป็น workspace โทนเทาเข้ม: sidebar ย่อได้ หัวข้อของแต่ละหน้า และกลุ่ม controls
ค่าเริ่มต้นขนาดหน้าต่าง 92% × 88% ของพื้นที่หน้าจอ จำกัดที่ 920 × 660 px;
ส่ง `config.Size` เพื่อใช้ขนาดเดิมที่ caller กำหนดเองได้ เมื่อกว้างน้อยกว่า 680 px
sidebar จะย่อเป็น icon rail โดยอัตโนมัติ พร้อมชื่อแท็บเมื่อ hover
หน้าแรกเป็น Quick Actions; การย้าย controls เข้า section ไม่เปลี่ยน profile IDs หรือปุ่มลัด

Minimize ย่อทั้งหน้าต่างด้วย UIScale ไปยังปุ่มเรียกคืนตรงกลางด้านล่างหน้าจอ
กดปุ่มนั้น, ใช้ window shortcut (ค่าเริ่มต้น K) หรือ SelectTab เพื่อเรียกคืน
รักษา Size, ตำแหน่งที่ลากไว้, แท็บ และสถานะ controls; การย่อไม่ปิดฟีเจอร์ที่กำลังทำงาน
`Window:SetMinimized(boolean)` / `Window:IsMinimized()` ใช้ควบคุมสถานะนี้ได้
`SetVisible(false)` ซ่อนทั้งหน้าต่างและปุ่มเรียกคืน ส่วน `Toggle()` จะเรียกคืนก่อนหากย่ออยู่
animation ใช้ scope แยกและยกเลิก tween/Completed handlers เมื่อคำสั่งใหม่มาแทนหรือ Destroy
`ctx.GetScale()` ช่วยแปลง AbsoluteSize/AbsoluteContentSize กลับเป็น layout units
เพื่อไม่ให้ responsive breakpoint และความสูงเนื้อหาเปลี่ยนเพราะ animation

ขอบหน้าต่างใช้รัศมีเดียวกันที่ shell และพื้นหลัง sidebar; TopBar โปร่งใส
เพราะ [UICorner ไม่ clip descendants](https://create.roblox.com/docs/reference/engine/classes/UICorner)
พื้นหลัง sidebar จึงวาดมุมล่างซ้ายของตัวเอง แล้วเติมเฉพาะขอบบน/ขวาที่อยู่ภายใน shell
ไม่อาศัย ClipsDescendants เพื่อบังมุมโค้ง และไม่ต้อง render UI ลง CanvasGroup texture

`window:CreateTab(name, icon, { Description = "...", Order = -10 })` เพิ่มคำอธิบายหน้า
และเรียง navigation ได้ argument ตัวที่สามไม่บังคับ รูปแบบเดิมยังใช้งานได้
`CreateButton` ใช้ความกว้างตามข้อความตามค่าเริ่มต้นและไม่ย่อขนาดปุ่มตอนกด
เพิ่ม config `Variant = "Primary" | "Secondary" | "Ghost" | "Danger"`
เพื่อแยกลำดับความสำคัญของคำสั่ง

ใช้ `tab:CreateActionGroup({ Cards = true, Columns = 2, MinWidth = 210 })`
แล้วเรียก `group:CreateButton(text, callback, { Icon = "...", Description = "..." })`
เพื่อสร้างการ์ดคำสั่ง มี icon, ชื่อ และคำอธิบาย; กลุ่มจะเปลี่ยนเป็นคอลัมน์เดียวเมื่อแคบ
ถ้าไม่ส่ง `Cards = true` จะได้แถวปุ่มสูง 38 px สำหรับคำสั่งรอง
grid เป็นเจ้าของขนาดปุ่ม และคำนวณความสูงจาก `AbsoluteContentSize`
ใช้ ActionGroup สำหรับปุ่มเท่านั้น; controls ที่มีค่าให้ใส่ใน Section
การ Destroy กลุ่มต้องยกเลิก callback และ connection ของทุกปุ่มด้วย

การเปลี่ยนหน้าตานี้ไม่ได้เพิ่มระบบ reactive rendering
`SetTheme` ยังคงแก้ตารางสีที่การสร้าง/อัปเดตครั้งถัดไปอ่าน ไม่ repaint ทุก instance ทันที
Tokens เป็นค่าร่วมแบบอ่านอย่างเดียวตอน runtime; แก้ source แล้ว build เมื่อต้องการเปลี่ยน
ค่าระยะเฉพาะ component ยังอยู่ในไฟล์ component เพื่อไม่ทำให้รูปแบบที่ต่างกันผูกกันทั้งหมด

## Module และ component contract

แต่ละไฟล์รับ `local import = ...` เพื่อเรียก dependency จาก registry ภายในไฟล์ generated
ใช้ชื่อ module แบบ literal เช่น `import("core/Lifecycle")` ไม่ใช้ `require(script.Parent...)`
build ตรวจ dependency ที่ขาดและวงจร import ก่อนสร้าง artifact
ไฟล์ภายในเป็น factory ที่คืน constructor; ไม่มีการสร้าง GUI เมื่อเพียง import module

Constructor ของ control รับ `ctx` ตามด้วย arguments ของ API เดิม เช่น
`Slider(ctx, text, min, max, default, callback, options)`
`ctx` เป็น dependencies สำหรับ container นี้ ไม่ใช่ทั้ง App หรือ Window:

| Field | ใช้เมื่อ |
|---|---|
| `Parent` | parent Instance ที่ component ต้อง mount ลงไป |
| `Scope` | tracker ของเจ้าของ; component สร้าง tracker ลูกของตัวเอง |
| `Theme`, `Primitives` | วาดและอัปเดต appearance |
| `Register(obj, scope, resettable)` | ผูก Destroy, setters และ ResetAll registration |
| `Section` | ต้องการ separator/appearance ภายใน section |
| `Input`, `Capture` | control รับปุ่มลัดหรือ capture key |
| `BindSliderDrag` | control เป็น slider; dispatcher ร่วมต่อหน้าต่าง |
| `BindContainer` | Section ต้องติดตั้ง Create* methods ให้ลูก |

ให้อ่านเฉพาะ fields ที่ component ใช้ เช่น Label ไม่ต้องรู้จัก Input หรือ Capture
`Toggle.Root`, `Header`, `Scope`, `LabelOffset` และ `Slider.Root` เป็น hooks ภายในสำหรับ composition
ไม่ต้องใช้ hooks เหล่านี้เมื่อเรียก API เดิมผ่าน Tab/Section

Hotkey เป็นปุ่มจับและเรียก shortcut ขนาดเล็กข้าง toggle ส่วน Keybind เป็นแถวตั้งค่าปุ่มลัด
ที่มี `OnChanged`/`OnListeningChanged` และ Escape เพื่อยกเลิก capture; แยกกันเพื่อรักษาพฤติกรรมเดิม

## ประกอบและเพิ่ม controls

`tab:CreateToggle(...)` ส่งต่อไป SettingRow ซึ่งสร้าง Toggle แล้วเพิ่ม Hotkey/Slider ตาม config
Slider มี presentation ปกติและ `Compact` แต่ใช้การ clamp, quantize, drag, text input และ callback ร่วมกัน
คง `GetSlider()` / `SetSlider(value, silent)` ของ toggle เดิม
slider ที่ฝังอยู่ไม่ลงทะเบียน ResetAll แยก: Reset ของ toggle ยังรีเซ็ตเฉพาะสวิตช์ตามพฤติกรรมเดิม

เมื่อเพิ่ม component:

1. สร้างไฟล์ใน `ui/components/` รับ ctx และคืน handle ที่มี `Destroy()`/`SetVisible()` ตามหน้าที่
2. สร้าง tracker ลูกจาก `ctx.Scope` และลงทะเบียน events/tasks ทุกตัว
3. งานที่ yield ให้ผ่าน `scope:Invoke` / `scope:Spawn` / `scope:Delay`
4. เรียก `ctx.Register(handle, scope, resettable)`; เฉพาะ control ที่มีค่าและ Reset จึงส่ง true
5. เพิ่ม constructor ใน `ui/layout/Container.lua` เมื่อต้องการเปิดเป็น Create* API
6. ถ้าเป็นชุด controls ให้ประกอบใน `ui/blocks/` และส่ง Scope/Parent ของเจ้าของไปยังลูก
7. เพิ่มกรณีทดสอบพฤติกรรมหรือ ownership ที่เปลี่ยน แล้ว build

Window → Tab → Section → Control เป็นลำดับ ownership
การปิดเจ้าของจะ cleanup ลูกด้วย; scope ของ slider/hotkey ที่ฝังอยู่ขึ้นกับ toggle
ห้ามเพิ่ม global InputChanged/InputEnded แยกต่อ slider
UI ยังใช้ tracker เดิมที่รักษา callbacks แบบ synchronous เมื่อไม่ yield;
ไม่ได้สลับไปใช้ Infrastructure.Scope ซึ่งมี contract ต่างกัน

## Build และแจกจ่าย

```powershell
python tools/build.py
python tools/build.py --ui-only
python tools/build.py --check-ui
```

คำสั่งแรกสร้างทั้ง `DiqUILib.lua` และ `dist/Diq.lua`
`--ui-only` สร้างเฉพาะ UI artifact; `--check-ui` ไม่เขียนไฟล์และคืน error ถ้า artifact ไม่ตรง source
ไฟล์ `.lua` ใน `ui/` ถูกค้นหาอัตโนมัติและรวมเป็น factories ใน registry ภายใน
ไม่ต้องเพิ่ม components เหล่านี้ใน root `module-manifest.json`
root manifest ยังมี `DiqUILib` หนึ่ง entry และ Main ยังดาวน์โหลด UI เพียงไฟล์เดียวจาก commit เดิม
commit `ui/` และ `DiqUILib.lua` ที่สร้างใหม่พร้อมกัน; `dist/` ยังเป็น output ที่ถูก gitignore
ยังต้อง publish ตาม workflow เดิมก่อน remote loader จะได้รับรุ่นใหม่

Loading ใน Main ยังเป็น bootstrap ที่ไม่พึ่ง UI Lib เพื่อแสดงก่อนดาวน์โหลดโมดูลได้

## ตรวจสอบ

```powershell
python tests/test_ui_build.py
python tests/run_infrastructure.py --luau-dir C:/path/to/luau
```

runner ตรวจ artifact freshness และ compile ทั้ง source components, root modules และ bundle
UI suite เดิมตรวจ compatibility; Components suite ทดสอบ component เดี่ยว, composition,
section nesting, cancellation, window replacement และการ rollback เมื่อสร้าง UI ล้มเหลว
Loader/ControlCenter suites ใช้ generated UI จริง
ทั้งหมดเป็น static/engine mocks ไม่ยืนยัน layout, input timing หรือสิทธิ์บน executor จริง

Live acceptance: เปิดทุกแท็บ, ทดลอง slider ทั้งสองรูปแบบด้วยเมาส์/สัมผัส/พิมพ์ค่า,
capture/cancel keybind, สร้าง controls ใน section ซ้อน, เปลี่ยน dropdown options,
ปิด/เปิดหน้าต่างซ้ำ และตรวจ Loading/notifications รวมถึง fallback ไป PlayerGui
