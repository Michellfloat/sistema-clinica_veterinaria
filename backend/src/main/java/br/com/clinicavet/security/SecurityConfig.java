package br.com.clinicavet.security;

import br.com.clinicavet.repository.UsuarioRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;
import java.util.List;

@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtService jwtService;
    private final UsuarioRepository usuarioRepository;

    @Value("${app.cors.allowed-origins}")
    private String origensPermitidas;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)
            .cors(c -> c.configurationSource(corsConfigurationSource()))
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(a -> a
                .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                .requestMatchers("/api/auth/login", "/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html",
                                 "/actuator/health/**").permitAll()
                .requestMatchers("/api/usuarios/**", "/api/logs/**").hasRole("ADMIN")
                .requestMatchers("/api/tutores/**", "/api/dashboard").hasAnyRole("ADMIN", "USUARIO")
                .requestMatchers(HttpMethod.GET, "/api/pets/**", "/api/agendamentos/**")
                    .hasAnyRole("ADMIN", "USUARIO", "TUTOR", "PET")
                .requestMatchers("/api/pets/**", "/api/agendamentos/**").hasAnyRole("ADMIN", "USUARIO")
                .anyRequest().authenticated())
            .exceptionHandling(e -> e
                .authenticationEntryPoint((req, res, ex) -> {
                    boolean expirado = req.getAttribute(JwtAuthFilter.ATRIBUTO_EXPIRADO) != null;
                    escrever(res, 401, "Unauthorized",
                            expirado ? "SessÃ£o expirada. FaÃ§a login novamente." : "AutenticaÃ§Ã£o necessÃ¡ria.");
                })
                .accessDeniedHandler((req, res, ex) ->
                    escrever(res, 403, "Forbidden", "VocÃª nÃ£o tem permissÃ£o para acessar este recurso.")))
            .addFilterBefore(new JwtAuthFilter(jwtService, usuarioRepository), UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    private void escrever(jakarta.servlet.http.HttpServletResponse res, int status, String erro, String msg)
            throws java.io.IOException {
        res.setStatus(status);
        res.setContentType(MediaType.APPLICATION_JSON_VALUE);
        res.setCharacterEncoding("UTF-8");
        res.getWriter().write("{\"status\":" + status + ",\"erro\":\"" + erro + "\",\"mensagem\":\"" + msg + "\"}");
    }

    @Bean
    public UserDetailsService userDetailsService() {
        return email -> usuarioRepository.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException("UsuÃ¡rio nÃ£o encontrado"));
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration config) throws Exception {
        return config.getAuthenticationManager();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration cfg = new CorsConfiguration();
        cfg.setAllowedOrigins(Arrays.stream(origensPermitidas.split(",")).map(String::trim).toList());
        cfg.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        cfg.setAllowedHeaders(List.of("Authorization", "Content-Type"));
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", cfg);
        return source;
    }
}