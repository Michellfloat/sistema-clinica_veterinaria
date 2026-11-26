package br.com.clinicavet.controller;

import br.com.clinicavet.dto.AgendamentoDataRequest;
import br.com.clinicavet.dto.AgendamentoRequest;
import br.com.clinicavet.dto.AgendamentoResponse;
import br.com.clinicavet.dto.AgendamentoStatusRequest;
import br.com.clinicavet.model.Usuario;
import br.com.clinicavet.service.AgendamentoService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/agendamentos")
@RequiredArgsConstructor
@Tag(name = "Agendamentos")
public class AgendamentoController {

    private final AgendamentoService service;

    @GetMapping
    @Operation(summary = "Lista agendamentos ordenados por dia, com dados do tutor e do pet")
    public List<AgendamentoResponse> listar(@AuthenticationPrincipal Usuario usuario) { return service.listar(usuario); }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public AgendamentoResponse criar(@Valid @RequestBody AgendamentoRequest req, @AuthenticationPrincipal Usuario usuario) {
        return service.criar(req, usuario);
    }

    @PatchMapping("/{id}/data")
    @Operation(summary = "Atualiza a data de um agendamento (gera registro em log_agendamento)")
    public AgendamentoResponse atualizarData(@PathVariable Long id, @Valid @RequestBody AgendamentoDataRequest req) {
        return service.atualizarData(id, req);
    }

    @PatchMapping("/{id}/status")
    public AgendamentoResponse atualizarStatus(@PathVariable Long id, @Valid @RequestBody AgendamentoStatusRequest req) {
        return service.atualizarStatus(id, req);
    }
}