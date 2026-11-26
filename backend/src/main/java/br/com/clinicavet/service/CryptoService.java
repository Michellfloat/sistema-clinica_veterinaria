package br.com.clinicavet.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.Cipher;
import javax.crypto.Mac;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.HexFormat;

/**
 * ProteÃ§Ã£o de dados pessoais (LGPD): AES-256-GCM para cifrar o CPF e HMAC-SHA256 para
 * gerar um Ã­ndice pesquisÃ¡vel/Ãºnico sem expor o valor original.
 * Formato do cifrado: Base64( IV[12] + CIPHERTEXT + TAG[16] ).
 */
@Service
public class CryptoService {

    private static final int IV_BYTES = 12;
    private static final int TAG_BITS = 128;

    private final SecretKeySpec chaveAes;
    private final SecretKeySpec chaveHmac;
    private final SecureRandom random = new SecureRandom();

    public CryptoService(@Value("${app.crypto.secret}") String segredo,
                         @Value("${app.crypto.hash-secret}") String segredoHash) {
        this.chaveAes = new SecretKeySpec(sha256(segredo), "AES");
        this.chaveHmac = new SecretKeySpec(sha256(segredoHash), "HmacSHA256");
    }

    public String cifrar(String textoPuro) {
        try {
            byte[] iv = new byte[IV_BYTES];
            random.nextBytes(iv);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, chaveAes, new GCMParameterSpec(TAG_BITS, iv));
            byte[] cifrado = cipher.doFinal(textoPuro.getBytes(StandardCharsets.UTF_8));
            byte[] saida = new byte[iv.length + cifrado.length];
            System.arraycopy(iv, 0, saida, 0, iv.length);
            System.arraycopy(cifrado, 0, saida, iv.length, cifrado.length);
            return Base64.getEncoder().encodeToString(saida);
        } catch (Exception e) {
            throw new IllegalStateException("Falha ao criptografar dado sensÃ­vel", e);
        }
    }

    public String decifrar(String base64) {
        try {
            byte[] entrada = Base64.getDecoder().decode(base64);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, chaveAes, new GCMParameterSpec(TAG_BITS, entrada, 0, IV_BYTES));
            byte[] puro = cipher.doFinal(entrada, IV_BYTES, entrada.length - IV_BYTES);
            return new String(puro, StandardCharsets.UTF_8);
        } catch (Exception e) {
            throw new IllegalStateException("Falha ao descriptografar dado sensÃ­vel", e);
        }
    }

    /** HMAC-SHA256 em hexadecimal (64 caracteres) do valor informado. */
    public String hash(String valor) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(chaveHmac);
            return HexFormat.of().formatHex(mac.doFinal(valor.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException("Falha ao gerar hash", e);
        }
    }

    private static byte[] sha256(String s) {
        try {
            return MessageDigest.getInstance("SHA-256").digest(s.getBytes(StandardCharsets.UTF_8));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}