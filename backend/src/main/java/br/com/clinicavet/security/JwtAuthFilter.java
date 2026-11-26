package br.com.clinicavet.security;

import br.com.clinicavet.repository.UsuarioRepository;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/** LÃª o header Authorization: Bearer ... e autentica a requisiÃ§Ã£o. (NÃ£o Ã© @Component de propÃ³sito: Ã© registrado no SecurityFilterChain.) */
@Slf4j
public class JwtAuthFilter extends OncePerRequestFilter {

    public static final String ATRIBUTO_EXPIRADO = "jwt.expirado";

    private final JwtService jwtService;
    private final UsuarioRepository usuarioRepository;

    public JwtAuthFilter(JwtService jwtService, UsuarioRepository usuarioRepository) {
        this.jwtService = jwtService;
        this.usuarioRepository = usuarioRepository;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            try {
                String email = jwtService.extrairEmail(header.substring(7));
                usuarioRepository.findByEmail(email).filter(u -> u.isEnabled()).ifPresent(usuario -> {
                    var auth = new UsernamePasswordAuthenticationToken(usuario, null, usuario.getAuthorities());
                    auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                    SecurityContextHolder.getContext().setAuthentication(auth);
                });
            } catch (ExpiredJwtException e) {
                request.setAttribute(ATRIBUTO_EXPIRADO, true);
            } catch (JwtException | IllegalArgumentException e) {
                log.debug("Token invÃ¡lido: {}", e.getMessage());
            }
        }
        chain.doFilter(request, response);
    }
}