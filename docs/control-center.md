# Diq Control Center

เพิ่มแท็บ Profiles, Keybinds, Performance, Diagnostics และ Quick Actions
Main ยังโหลดบน client ผ่าน executor ตามเดิม และไฟล์โมดูลยังคืน public API เดิม

## เริ่มใช้งาน

สร้างไฟล์รวมด้วย `python tools/build.py` แล้วใช้ `dist/Diq.lua`
หากใช้ Main แบบ remote ให้อัปโหลดไฟล์ทั้งหมดรวม Preferences.lua, Keybinds.lua,
ControlCenter.lua ใน commit เดียวกัน Main จะโหลด 11 โมดูลจาก SHA เดียว

ปุ่มเริ่มต้น: K เปิด/ซ่อนหน้าต่าง, F1 เปิด Quick Actions, End หยุดทุกฟีเจอร์
F = Fly, G = Speed, V = NoClip, B = Anti-Fling, Q = Aim Assist
ทุกปุ่มเปลี่ยนหรือถอนการผูกได้ใน Keybinds ฟีเจอร์อื่นเริ่มจากไม่มีปุ่มลัด

## Profiles

- ตั้งค่าในแท็บฟีเจอร์ แล้วกรอก Profile Name และกด Save Named Profile
- ใช้ชื่อเดิมแล้วกด Load Named Profile เพื่อโหลด; Save ชื่อเดิมจะเขียนทับ
- เก็บไฟล์ `DiqProfiles/<PlaceId>/<name>.json` ภายในพื้นที่ไฟล์ของ executor
  ไม่ใช่ path ของ repository และไม่รับ path ที่ผู้ใช้กำหนดเอง
- ชื่อใช้ตัวอักษรอังกฤษ ตัวเลข `_` หรือ `-` จำนวน 1–40 ตัว
- ถ้า filesystem/clipboard ใช้ไม่ได้ ให้ใช้ Export JSON แล้วคัดลอกจากช่องข้อความ
  เมื่อต้องการโหลดให้วางในช่อง Profile JSON แล้วกด Import JSON
- เก็บค่าฟีเจอร์ทั้งหมดที่มีใน UI รวม slider ย่อย, performance และปุ่มลัด
  รวมสถานะเปิด/ปิดด้วย จึงอาจเปิดฟีเจอร์หลัง Import/Load; ไม่มี auto-load เมื่อเริ่มใหม่
- รูปแบบ `DiqProfile` เวอร์ชัน 1 จำกัด 64 KiB และต้องเป็น PlaceId เดียวกัน
  ตรวจชนิดข้อมูล ช่วงตัวเลข รายการตัวเลือก key conflicts และความครบของ snapshot ก่อนแก้สถานะ
- หาก setter ล้มเหลว จะพยายามคืนค่าที่เปลี่ยนไป หากคืนไม่ครบจะแจ้งให้ใช้ Stop All
  ไม่ใช่ transaction ของ Roblox engine และไม่คืน side effects ที่เกมสร้างขึ้นเอง
- Restore Defaults คืนค่าฟีเจอร์, performance และปุ่มลัด; ไม่ลบไฟล์โปรไฟล์

## Keybinds

คลิกปุ่มชื่อคีย์เพื่อจับปุ่มใหม่; Escape ยกเลิก; ปุ่มซ้ำถูกปฏิเสธพร้อมคืนค่าหน้าจอ
เลือก Toggle หรือ Hold สำหรับฟีเจอร์ ส่วนคำสั่งเปิดหน้าต่าง/เปิด Quick Actions/Stop All เป็น Toggle
Hold เปิดเมื่อกดและปิดเมื่อปล่อย รวมถึงเมื่อเปลี่ยนปุ่ม เปิดช่องพิมพ์ เปิดเมนู
เสีย focus หรือ character ถูกนำออก ปุ่มลัดไม่ทำงานขณะพิมพ์หรือกำลังจับคีย์
Aim พักระหว่างจับคีย์และกลับมาตามสถานะเดิมเมื่อจับเสร็จ

ระบบนี้รองรับ keyboard ในรอบนี้ ยังไม่มี gamepad/touch binding
API ปุ่มลัดเดิมของ Aimbot ยังคงใช้ได้เมื่อโหลดโมดูลแยกโดยไม่ใช้ ControlCenter
เมื่อผ่าน Main ให้เปลี่ยนปุ่มจาก Keybinds เพราะ dispatcher กลางเป็นเจ้าของ shortcut

## Performance

| Preset | ESP updates | Visuals ที่เปิดพร้อมกัน | ระยะสูงสุดเพิ่มเติม | Aim full scan |
|---|---:|---:|---:|---:|
| Low | สูงสุดประมาณ 20/s | 20 ผู้เล่นใกล้ที่สุด | 500 studs | ประมาณ 4/s |
| Balanced | สูงสุดประมาณ 30/s | 50 ผู้เล่นใกล้ที่สุด | 1500 studs | ประมาณ 10/s |
| High (ค่าเริ่มต้น) | ทุก render frame | ไม่เพิ่มข้อจำกัด | ไม่เพิ่มข้อจำกัด | ประมาณ 10/s |

ใช้ค่าระยะ ESP ที่ผู้ใช้ตั้งร่วมด้วย โดยเลือกขอบเขตที่แคบกว่า
Preset ไม่เปลี่ยนตัวเลือก Boxes/Names/Highlights และไม่เปิดฟีเจอร์
จำกัดจำนวน visual ที่ active; วัตถุที่เคยสร้างอาจยังเก็บแบบซ่อนเพื่อใช้ซ้ำ
การกรองผู้เล่นยังทำตามจำนวนผู้เล่น และจัดลำดับระยะเมื่อเกิน budget
ความถี่จริงปัดตามเวลาเฟรม การแทนเป้าหมายที่ใช้ไม่ได้อาจสแกนทันที
ไม่มีการลดความถี่ physics ของ Movement/Hitbox หรือการปรับกล้องของเป้าหมายปัจจุบัน

## Diagnostics

Refresh Report แสดงจำนวน scheduler tasks, failures, capability status และรายงาน JSON
แยก `Present; untested`, `Unavailable` และผลการเรียกจริงครั้งล่าสุด
Test Invisible Drawing ทดสอบเฉพาะ Square create/remove ไม่ได้พิสูจน์ Drawing ทุกชนิด
ไม่ทดสอบ mouse output ด้วยการขยับเมาส์ และไม่มีการยิง HTTP หรือเรียก VirtualUser อัตโนมัติ

รายงานรวม `app:GetDiagnostics()`, active feature states, budget และ errors ของ ControlCenter ล่าสุดไม่เกิน 10 รายการ
เวลาของ scheduler และ Aim เป็นวินาที (`Calls`, `Total`, `Max`, `Failures`)
ค่าเฉลี่ยต่อ call คำนวณ `Total / Calls` เมื่อ Calls มากกว่า 0
ไม่ใช่การเก็บ exception ทั้งหมดจาก engine/executor
รายงานไม่รวม UserId, JobId, script contents หรือ response bodies

Sample Frame Times เก็บ RenderStepped delta ประมาณ 10 วินาที สูงสุด 10,000 ตัวอย่าง
รายงาน MeanMs/P95Ms/P99Ms และการเสีย focus; timeout หลัง 15 วินาทีหากเฟรมไม่พอ
หมดช่วงแล้วหยุด connection และ timer อัตโนมัติ การปิดหน้าต่างยกเลิก sample ที่ค้าง
เป็น frame interval ของ client ทั้งระบบ ไม่ใช่เวลาที่ Diq ใช้เพียงอย่างเดียว
เทียบ preset โดยใช้ฉาก อุปกรณ์ กล้อง และ feature settings เดียวกัน

## Quick Actions

พิมพ์ Find Setting แล้วออกจากช่อง เลือกผลลัพธ์และกด Open Selected Setting
เพื่อเปิดแท็บที่เกี่ยวข้อง หรือ Toggle Selected Setting สำหรับค่าประเภทเปิด/ปิด
มีทางลัดไป Profiles/Diagnostics และ Stop All Features
Stop All ปิดฟีเจอร์และคืน property claims โดยเก็บค่าที่ตั้งไว้และไม่ปิด UI
ยกเลิก sample และ queued actions เช่น Rejoin ที่ยังรออยู่ด้วย; หากต้องการปิด session ทั้งหมดให้ปิดหน้าต่าง

## โครงสร้างสำหรับพัฒนา

- Preferences.lua: schema, snapshot/validation/apply/rollback และ filesystem adapter
- Keybinds.lua: central dispatcher, conflict validation, Hold/Toggle และ cleanup
- ControlCenter.lua: ผูก settings กับ widgets/module setters และสร้างแท็บเครื่องมือ
- `app.Tools` ให้ใช้ ExportProfile, ApplyProfile, Reset, StopAll, SetPerformance,
  CapabilitiesSnapshot, ProbeDrawing, Report และ SampleFrames
- `app.Tools.Settings:Apply(values)` รับ partial update; profile import ต้องเป็น full snapshot
- Setting IDs ของ schema v1 สร้างจาก tab prefix และ label ภาษาอังกฤษที่จัดส่ง
  การเปลี่ยนชื่อ/เพิ่ม/ลบ settings ต้องเพิ่ม migration หรือเปลี่ยน schema version ก่อนรับโปรไฟล์เก่า
- callback ของ settings ต้อง synchronous; UI setter แบบ `silent` เปลี่ยนภาพโดยไม่ยิง callback ซ้ำ

## การตรวจสอบและข้อจำกัด

รัน `tests/run_infrastructure.py`, `tests/run_esp.py`, `tests/run_aimbot.py` กับ Luau CLI ทางการ
ControlCenter suite ใช้ production Main/UI/feature modules กับ engine mocks
ครอบคลุม UI buttons, profile validation/rollback, filesystem fallback, conflict/capture/hold,
performance limits, quick search, sampling/timeout และ repeated cleanup
JSON codec และ filesystem เป็น mock; ไม่ได้ทดสอบ implementation ของ Roblox JSON parser หรือสิทธิ์ executor จริง
ยังต้องตรวจ UI layout, scroll/copy/paste, keyboard capture และการคืนค่าบน Roblox/executor จริง

อ้างอิง engine APIs โดยตรง:
[HttpService](https://create.roblox.com/docs/reference/engine/classes/HttpService),
[UserInputService](https://create.roblox.com/docs/reference/engine/classes/UserInputService),
[Design for performance](https://create.roblox.com/docs/performance-optimization/design)
Filesystem, clipboard, Drawing และ mouse output เป็น executor-specific APIs ไม่ได้เป็นส่วนหนึ่งของ Roblox Docs
