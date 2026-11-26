package br.com.clinicavet.util;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class CpfUtilTest {

    @Test
    void cpfValido_aceitaComEsemMascara() {
        assertTrue(CpfUtil.valido("529.982.247-25"));
        assertTrue(CpfUtil.valido("52998224725"));
    }

    @Test
    void cpfInvalido_rejeitaDigitosErradosESequencias() {
        assertFalse(CpfUtil.valido("123.456.789-00"));
        assertFalse(CpfUtil.valido("111.111.111-11"));
        assertFalse(CpfUtil.valido("123"));
        assertFalse(CpfUtil.valido(null));
    }

    @Test
    void mascarar_escondeDigitosSensiveis() {
        assertEquals("***.982.247-**", CpfUtil.mascarar("529.982.247-25"));
    }
}