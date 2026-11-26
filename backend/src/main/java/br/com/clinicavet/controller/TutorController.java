package br.com.clinicavet.controller;

import br.com.clinicavet.dto.TutorRequest;
import br.com.clinicavet.dto.TutorResponse;
import br.com.clinicavet.service.TutorService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/tutores")
@RequiredArgsConstructor
@Tag(name = "Tutores")
public class TutorController {

    private final TutorService service;

    @GetMapping
    @Operation(summary = "Lista tutores; com ?busca= filtra por nome, e-mail, telefone ou CPF")
    public List<TutorResponse> listar(@RequestParam(required = false) String busca) {
        return service.listar(busca);
    }

    @GetMapping("/{id}")
    public TutorResponse buscar(@PathVariable Long id) { return service.buscarPorId(id); }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public TutorResponse criar(@Valid @RequestBody TutorRequest req) { return service.criar(req); }

    @PutMapping("/{id}")
    @Operation(summary = "Edita os dados de um tutor jÃ¡ cadastrado")
    public TutorResponse atualizar(@PathVariable Long id, @Valid @RequestBody TutorRequest req) {
        return service.atualizar(id, req);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void remover(@PathVariable Long id) { service.inativar(id); }
}