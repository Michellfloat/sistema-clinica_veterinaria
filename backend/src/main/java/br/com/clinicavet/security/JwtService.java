package br.com.clinicavet.security;

import br.com.clinicavet.model.Usuario;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

/** GeraÃ§Ã£o e validaÃ§Ã£o do token JWT (expiraÃ§Ã£o curta, padrÃ£o 1 minuto). */
@Service
public class JwtService {

    private final SecretKey chave;
    private final long expiracaoMs;

    public JwtService(@Value("${app.jwt.secret}") String segredo,
                      @Value("${app.jwt.expiration-ms}") long expiracaoMs) {
        byte[] bytes = segredo.getBytes(StandardCharsets.UTF_8);
        if (bytes.length < 32) {
            throw new IllegalStateException("app.jwt.secret deve ter pelo menos 32 caracteres.");
        }
        this.chave = Keys.hmacShaKeyFor(bytes);
        this.expiracaoMs = expiracaoMs;
    }

    public long getExpiracaoMs() { return expiracaoMs; }

    public String gerarToken(Usuario usuario, Date expiracao) {
        return Jwts.builder()
                .subject(usuario.getEmail())
                .claim("perfil", usuario.getPerfil().getNome())
                .claim("nome", usuario.getNome())
                .issuedAt(new Date())
                .expiration(expiracao)
                .signWith(chave)
                .compact();
    }

    public Date calcularExpiracao() {
        return new Date(System.currentTimeMillis() + expiracaoMs);
    }

    /** LanÃ§a JwtException se o token for invÃ¡lido, adulterado ou expirado. */
    public String extrairEmail(String token) {
        return claims(token).getSubject();
    }

    private Claims claims(String token) {
        return Jwts.parser().verifyWith(chave).build().parseSignedClaims(token).getPayload();
    }
}