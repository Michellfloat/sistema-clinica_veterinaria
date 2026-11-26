package br.com.clinicavet.controller;

import br.com.clinicavet.dto.UsuarioRequest;
import br.com.clinicavet.dto.UsuarioResponse;
import br.com.clinicavet.service.UsuarioService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/usuarios")
@RequiredArgsConstructor
@Tag(name = "UsuÃ¡rios (ADMIN)")
public class UsuarioController {

    private final UsuarioService service;

    @GetMapping
    public List<UsuarioResponse> listar() { return service.listar(); }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public UsuarioResponse criar(@Valid @RequestBody UsuarioRequest req) { return service.criar(req); }

    @PutMapping("/{id}")
    public UsuarioResponse atualizar(@PathVariable Long id, @Valid @RequestBody UsuarioRequest req) { return service.atualizar(id, req); }
}