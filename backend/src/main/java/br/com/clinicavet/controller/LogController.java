package br.com.clinicavet.controller;

import br.com.clinicavet.dto.LogResponse;
import br.com.clinicavet.service.LogService;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/logs")
@RequiredArgsConstructor
@Tag(name = "Logs de atualizaÃ§Ã£o (ADMIN)")
public class LogController {

    private final LogService service;

    @GetMapping
    public List<LogResponse> listar() { return service.listarTodos(); }
}