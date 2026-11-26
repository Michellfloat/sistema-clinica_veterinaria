package br.com.clinicavet.service;

import br.com.clinicavet.dto.LoginRequest;
import br.com.clinicavet.dto.LoginResponse;
import br.com.clinicavet.mapper.UsuarioMapper;
import br.com.clinicavet.model.Usuario;
import br.com.clinicavet.security.JwtService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;

import java.util.Date;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final AuthenticationManager authenticationManager;
    private final JwtService jwtService;
    private final UsuarioMapper usuarioMapper;
    private final LogService logService;

    /** Falhas de autenticaÃ§Ã£o lanÃ§am BadCredentialsException (tratada no GlobalExceptionHandler => 401). */
    public LoginResponse login(LoginRequest req) {
        Authentication auth = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(req.email().trim().toLowerCase(), req.senha()));
        Usuario usuario = (Usuario) auth.getPrincipal();

        Date expiracao = jwtService.calcularExpiracao();
        String token = jwtService.gerarToken(usuario, expiracao);
        logService.usuario(usuario.getId(), "LOGIN", "Login realizado com sucesso", usuario.getEmail());

        return new LoginResponse(token, "Bearer", expiracao.getTime(), jwtService.getExpiracaoMs() / 1000,
                usuarioMapper.toResponse(usuario));
    }
}