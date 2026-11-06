class_name TekstEE
extends RefCounted
## Dekodowanie napisów 8-bitowych z plików EE (nazwy w archiwach SSA, nazwy graczy w scenariuszach, napisy tabel db).
## Polska wersja gry zapisuje je w Windows-1250 – pełna tablica 0x80–0xFF (wcześniej: tylko polskie litery,
## reszta jako Latin-1). Znaki 0x00–0x7F = ASCII; bajt 0 kończy napis.

const CP1250_80_FF := "€?‚?„…†‡?‰Š‹ŚŤŽŹ?‘’“”•–—?™š›śťžź\u00a0ˇ˘Ł¤Ą¦§¨©Ş«¬\u00ad®Ż°±˛ł´µ¶·¸ąş»Ľ˝ľżŔÁÂĂÄĹĆÇČÉĘËĚÍÎĎĐŃŇÓÔŐÖ×ŘŮÚŰÜÝŢßŕáâăäĺćçčéęëěíîďđńňóôőö÷řůúűüýţ˙"


static func cp1250(b: PackedByteArray) -> String:
	var s := ""
	for x in b:
		if x == 0:
			break
		s += char(x) if x < 0x80 else CP1250_80_FF[x - 0x80]
	return s
