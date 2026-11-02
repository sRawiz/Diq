# Diq infrastructure

ส่วน Profiles / Keybinds / Performance / Diagnostics / Quick Actions ดู [Control Center](control-center.md)

อ้างอิง Roblox Docs โดยตรง ตรวจเมื่อ 2 พฤศจิกายน 2026 ไม่มี community skill เป็น dependency
เอกสารอธิบาย runtime นี้ ไม่ได้เปลี่ยนโปรเจกต์เป็น Studio ModuleScripts

## Entry point และการแจกจ่าย

`Main.lua` ยังเป็น client entry point และคืน App เมื่อเริ่มสำเร็จ
เรียก `app:Destroy()` เพื่อปิด หรือใช้ `_G.DiqCleanup()` ตามเดิม
เมื่อเริ่มไม่สำเร็จจะ cleanup แล้วคืน `nil, error`

Main รับ options เป็น argument หรือ `_G.DiqOptions`:

- `Revision`: commit SHA เต็ม 40 ตัวของ repository ซึ่งต้องมีไฟล์ infrastructure ใหม่ด้วย
- หากไม่ระบุ revision จะ resolve `main` ครั้งเดียวผ่าน GitHub API แล้วใช้ SHA เดียวตลอด session
- `Sources`: ตาราง source strings สำหรับ local harness; ไม่ดาวน์โหลดในโหมดนี้
- `Factories`: ตารางฟังก์ชันโมดูลที่ compile แล้ว สำหรับ bundle/harness; ไม่ใช้ HTTP หรือ loadstring ภายใน

Source loader แยก download / compile / execution / validation errors
ข้อความ network failure ไม่บันทึก response body; การ pin SHA ไม่ใช่ sandbox หรือการรับรองความปลอดภัยของโค้ด
GitHub API อาจถูกจำกัด rate หรือ executor อาจไม่รองรับ HTTP; ใช้ SHA ที่ระบุไว้หรือ bundle

สร้าง bundle จากไฟล์ local:

```powershell
python tools/build.py
```

ผลลัพธ์คือ `dist/Diq.lua` ซึ่งเปิดแล้วนำโค้ดไปใช้ผ่าน executor ได้
ตัว bundle ไม่ต้องมี filesystem API, HTTP หรือ loadstring สำหรับโหลดโมดูลภายใน
ยังต้องมี client Roblox environment ตามฟีเจอร์ที่ใช้งาน และ Drawing สำหรับ overlay บางชนิด
ไม่ถือว่าการทดสอบ CLI ยืนยันสิทธิ์ executor

`module-manifest.json` ระบุ entry และรายชื่อโมดูลที่รวมใน bundle
เมื่อเพิ่มโมดูล ให้เพิ่มใน manifest และลงทะเบียนการโหลด/cleanup ใน Main
ไฟล์ bundle มี source digest สำหรับระบุ build และไม่ถูก commit โดยอัตโนมัติ

## Infrastructure.lua

Main สร้าง runtime หนึ่งชุดและส่ง `{ DeferInit = true, Runtime = runtime }` ให้โมดูล
ไฟล์โมดูลเดิมยัง return ตารางเดิม ใช้ public methods และรูปแบบ dot/colon เดิมได้
โมดูลที่เคย auto-init ยังรองรับการ execute โดยตรงโดยไม่มี Runtime
การแชร์ registry, input, scheduler และ property ownership ข้ามโมดูลใช้เมื่อโหลดผ่าน Main

| ส่วน | หน้าที่และสัญญา |
|---|---|
| Scope | เก็บ resource/cleanup function ตามลำดับ ย้อนลำดับเมื่อปิด ยกเลิกงานที่ยังรอหรือ yield และปิดซ้ำได้ |
| Properties | snapshot ตาม instance/property ก่อนแก้; owner ที่เข้ามาล่าสุดมี priority; release owner ไม่ทำลาย claim ที่เหลือ |
| Registry | เชื่อม PlayerAdded/Removing และ CharacterAdded/Removing; เก็บ parts จาก topology events แทน GetDescendants ทุกเฟรม |
| Input | หนึ่ง engine connection ต่อ event; subscriber มี handle ของตัวเอง; subscriber ล้มเหลวไม่ตัดการส่งต่อทั้งหมด |
| Scheduler | หนึ่ง connection ต่อ phase; หยุด phase เมื่อไม่มีงาน; ลดความถี่โดยไม่เร่งทำ catch-up จำนวนมากหลัง frame stall |
| Adapters | รวมจุดเรียก Drawing และ mouse output; ไม่สมมุติว่า executor ทุกตัวมี API เหมือนกัน |

Scope ใช้ `Add(resource, optionalKey)`, `Remove(key)`, `Delay(seconds, callback, ...)`, `Destroy()`
Scheduler ใช้ `Connect(name, phase, interval, callback, optionalOnError)` คืน handle ที่ Disconnect ได้
ชื่อ task ควรคงที่ต่อฟีเจอร์ เพื่อไม่ให้ diagnostic table โตตามงานชั่วคราว
callback ใน scheduler ต้องไม่ yield; งาน network/งานรอให้ใช้ scope แยก
Registry คืน borrowed snapshot/record ห้ามผู้ใช้แก้ตารางที่คืนมา

Property ownership ยึด baseline ก่อน claim แรก ไม่ใช่ค่าที่ owner อื่นเพิ่งแก้
การอัปเดต claim เดิมไม่แย่ง priority ของ owner ใหม่
เมื่อปล่อย claim สุดท้าย จะคืน baseline เฉพาะเมื่อค่าปัจจุบันยังตรงกับค่าที่ infrastructure เขียนล่าสุด
หากระบบเกมแก้ทับไปแล้วจะรักษาค่านั้น; ไม่สามารถตรวจแยกการเขียนจากภายนอกที่มีค่าเท่ากันได้

## ฟีเจอร์

- Movement และ Hitbox ใช้ PreSimulation และเปิด callbacks เฉพาะเมื่อใช้งาน
- Movement เก็บ collision claims แยก NoClip/Anti-Fling และคืนค่าเมื่อปิด/เกิดใหม่/เสีย focus
- Flight เก็บ reference ของ instances ที่สร้างเองและคืน PlatformStand ของ humanoid เดิม
- Hitbox snapshot part จริงก่อนแก้ ไม่ใช้ delay หลังเกิดใหม่หรือเดาขนาดเดิมจาก threshold
- ESP สร้าง visual ตามองค์ประกอบที่เปิด; Highlight-only ไม่มี Drawing และไม่มี 2D projection
- ESP เก็บ screen scratch table ต่อผู้เล่น และเขียนข้อความชื่อ/ระยะ/HP เมื่อค่าที่แสดงเปลี่ยน
- visual ที่เคยสร้างอาจถูกเก็บไว้แบบซ่อนเพื่อใช้ซ้ำ แต่ถูกลบเมื่อผู้เล่นออกหรือโมดูลถูกปิด
- Aim ยังคง callback กล้องตามลำดับ render เดิม; full scan จำกัดราว 10 Hz แม้ไม่มีเป้าหมาย
- การตรวจเป้าหมายปัจจุบันยังทำทุกเฟรม และเมื่อเป้าหมายใช้ไม่ได้สามารถค้นหาทดแทนทันที
- เมื่อหาไม่เจอ การค้นหาครั้งถัดไปอาจรอประมาณ 100 ms บวกการปัดตามเวลาเฟรม
- Fullbright ตอบสนอง Lighting.Changed และรวมการเปลี่ยนภายในประมาณ 100 ms ไม่เขียนทุก render frame
- Anti-AFK ปิดตัวเองและเผยแพร่สถานะเมื่อเรียก VirtualUser ไม่สำเร็จ การมี service ไม่ใช่หลักฐานว่ามีสิทธิ์เรียก

## UI lifecycle

แต่ละ control มี tracker ย่อย ยกเลิก input/tasks และถอนตัวจาก ResetAll เมื่อถูกลบ
section เป็นเจ้าของ controls ลูก และ dropdown option rebuild ปิด handlers ชุดก่อน
sliders ใช้ active drag dispatcher ของหน้าต่าง ไม่เพิ่ม global mouse handlers ต่อ slider
callbacks เริ่มทำงานทันที; callback ที่ไม่ yield ทำให้ state/ResetAll อัปเดตเสร็จแบบ synchronous
callback ที่ yield มี coroutine ของตัวเองและยังถูกยกเลิกเมื่อ control ถูกปิด
การตั้งค่าเดิมซ้ำบน slider ไม่เรียก callback ซ้ำ
Movement และ Misc มี SetStateListener เพื่อให้ UI รับสถานะจริงเมื่อ runtime เปลี่ยน state

## Diagnostics และการทดสอบ

`app:GetDiagnostics()` คืนสำเนา counters:

- `Tasks`: Calls / Total / Max / Failures ของ scheduler (เวลาเป็นวินาที)
- `Features.AimbotSystem`: Scans / Evaluations / Raycasts แบบสะสม
- `Features.ESPSystem`: Projections / Drawings ที่สร้างแบบสะสม ไม่ใช่จำนวนที่ยัง active

Counters เหล่านี้ไม่ใช่ FPS benchmark และไม่ใช่ GPU profiler
การเปรียบเทียบจริงต้องเก็บ frame time, p95/p99 และ memory บนอุปกรณ์และฉากเดียวกัน

```powershell
python tests/run_aimbot.py --luau-dir C:/path/to/luau
python tests/run_esp.py --luau-dir C:/path/to/luau
python tests/run_infrastructure.py --luau-dir C:/path/to/luau
```

Infrastructure suite ใช้ production modules และ engine mocks รวมถึง UI, Main และ bundle ที่ build จริง
ครอบคลุม ownership ซ้อนกัน, respawn, join/leave, ข้อผิดพลาดระหว่าง startup,
การรันซ้ำ, resource cancellation, lazy visuals และการจำกัดงานใน hot path
ไม่มี Studio/executor live test ในชุดนี้ ไม่จำลอง physics/network authority หรือภาพ GUI จริง

Live acceptance: ตรวจการเคลื่อนที่หลังย้าย phase, กล้องของเกมเป้าหมาย, การเกิดใหม่/streaming,
เปิดหลายฟีเจอร์ที่แก้ collision พร้อมกัน, input ขณะพิมพ์/เปลี่ยน keybind,
เปิดปิดหน้าต่างซ้ำ, Drawing ที่มี API ไม่ครบ และการอ่าน diagnostics เทียบก่อน/หลัง

## แหล่งทางการ

- [Design for performance](https://create.roblox.com/docs/performance-optimization/design)
- [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- [Task scheduler](https://create.roblox.com/docs/performance-optimization/microprofiler/task-scheduler)
- [Deferred engine events](https://create.roblox.com/docs/scripting/events/deferred)
- [Luau releases](https://github.com/luau-lang/luau/releases)
