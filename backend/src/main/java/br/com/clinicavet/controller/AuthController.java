package br.com.clinicavet.controller;

import br.com.clinicavet.dto.LoginRequest;
import br.com.clinicavet.dto.LoginResponse;
import br.com.clinicavet.dto.UsuarioResponse;
import br.com.clinicavet.mapper.UsuarioMapper;
import br.com.clinicavet.model.Usuario;
import br.com.clinicavet.service.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
@Tag(name = "AutenticaÃ§Ã£o")
public class AuthController {

    private final AuthService authService;
    private final UsuarioMapper usuarioMapper;

    @PostMapping("/login")
    @Operation(summary = "Autentica e devolve o JWT (expira em ~1 minuto)")
    public LoginResponse login(@Valid @RequestBody LoginRequest req) {
        return authService.login(req);
    }

    @GetMapping("/me")
    @Operation(summary = "Dados do usuÃ¡rio logado")
    public UsuarioResponse me(@AuthenticationPrincipal Usuario usuario) {
        return usuarioMapper.toResponse(usuario);
    }
}