-- Generated ECG pattern constants
-- Pattern A: ECG signals/Normal/100
-- Pattern B: ECG signals/PVC/208
-- Pattern C: ECG signals/LBBB/214

constant PATTERN_A : pattern_array := (
    to_signed(488, 12), to_signed(488, 12), to_signed(488, 12), to_signed(488, 12), to_signed(488, 12), to_signed(488, 12), to_signed(488, 12), to_signed(488, 12), 
    to_signed(512, 12), to_signed(498, 12), to_signed(488, 12), to_signed(483, 12), to_signed(473, 12), to_signed(478, 12), to_signed(473, 12), to_signed(458, 12)
);

constant PATTERN_B : pattern_array := (
    to_signed(3989, 12), to_signed(3989, 12), to_signed(3989, 12), to_signed(3989, 12), to_signed(3989, 12), to_signed(3989, 12), to_signed(3989, 12), to_signed(3989, 12), 
    to_signed(3977, 12), to_signed(3966, 12), to_signed(3963, 12), to_signed(3949, 12), to_signed(3937, 12), to_signed(3932, 12), to_signed(3934, 12), to_signed(3934, 12)
);

constant PATTERN_C : pattern_array := (
    to_signed(4000, 12), to_signed(4000, 12), to_signed(4000, 12), to_signed(4000, 12), to_signed(4000, 12), to_signed(4000, 12), to_signed(4000, 12), to_signed(4000, 12), 
    to_signed(3989, 12), to_signed(3967, 12), to_signed(3967, 12), to_signed(3971, 12), to_signed(3985, 12), to_signed(3989, 12), to_signed(3971, 12), to_signed(3960, 12)
);
