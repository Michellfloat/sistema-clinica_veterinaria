package br.com.clinicavet.service;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class CryptoServiceTest {

    private final CryptoService crypto = new CryptoService("segredo-aes-teste", "segredo-hmac-teste");

    @Test
    void cifrarEDecifrar_devolveOValorOriginal() {
        String cifrado = crypto.cifrar("52998224725");
        assertNotEquals("52998224725", cifrado);
        assertEquals("52998224725", crypto.decifrar(cifrado));
    }

    @Test
    void cifrar_usaIvAleatorio_mesmoTextoGeraCifradosDiferentes() {
        assertNotEquals(crypto.cifrar("52998224725"), crypto.cifrar("52998224725"));
    }

    @Test
    void hash_eDeterministicoCom64Caracteres() {
        assertEquals(crypto.hash("52998224725"), crypto.hash("52998224725"));
        assertEquals(64, crypto.hash("52998224725").length());
        assertNotEquals(crypto.hash("52998224725"), crypto.hash("11144477735"));
    }

    @Test
    void decifrar_comTextoAdulterado_lancaExcecao() {
        String cifrado = crypto.cifrar("52998224725");
        String adulterado = cifrado.substring(0, cifrado.length() - 4) + "AAAA";
        assertThrows(IllegalStateException.class, () -> crypto.decifrar(adulterado));
    }
}