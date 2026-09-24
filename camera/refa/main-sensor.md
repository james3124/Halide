# REF-A main sensor bring-up
Sensor: SENSOR_NAME_PLACEHOLDER

## Checklist
- [ ] 20/20 stills gate pass
- [ ] Flash on capture OK
- [ ] Flash off capture OK
- [ ] 1080p30 60s record OK
- [ ] No green frames

## Characteristics dump
Command:
  dumpsys media.camera

Expected: REF-A main sensor listed, no errors.
