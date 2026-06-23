extends RefCounted

const MIX_RATE := 22050


static func make_tone_wav(freq: float, duration: float, volume: float = 0.35) -> AudioStreamWAV:
	var sample_count := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / float(MIX_RATE)
		var envelope := 1.0 - (t / duration)
		var sample := sin(TAU * freq * t) * envelope * volume
		var int_sample := int(clampf(sample * 32767.0, -32768.0, 32767.0))
		data[i * 2] = int_sample & 0xFF
		data[i * 2 + 1] = (int_sample >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


static func make_generator_stream(buffer_length: float = 0.5) -> AudioStreamGenerator:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = buffer_length
	return gen