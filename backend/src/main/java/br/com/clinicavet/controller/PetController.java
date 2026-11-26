package br.com.clinicavet.controller;

import br.com.clinicavet.dto.PetRequest;
import br.com.clinicavet.dto.PetResponse;
import br.com.clinicavet.model.Usuario;
import br.com.clinicavet.service.PetService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/pets")
@RequiredArgsConstructor
@Tag(name = "Pets")
public class PetController {

    private final PetService service;

    @GetMapping
    public List<PetResponse> listar(@RequestParam(required = false) String busca, @AuthenticationPrincipal Usuario usuario) {
        return service.listar(busca, usuario);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public PetResponse criar(@Valid @RequestBody PetRequest req) { return service.criar(req); }

    @PutMapping("/{id}")
    public PetResponse atualizar(@PathVariable Long id, @Valid @RequestBody PetRequest req) { return service.atualizar(id, req); }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void remover(@PathVariable Long id) { service.inativar(id); }
}