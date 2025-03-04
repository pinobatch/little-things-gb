#!/usr/bin/env python3

print('section "pitch_table",ROM0,align[1]')
print("pitch_table::")
period = 131072.0 / 65.406
for i in range(64):
    print(" dw %d" % round(2048 - period))
    period = period / 1.059463094
