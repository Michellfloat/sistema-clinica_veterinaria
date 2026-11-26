package br.com.clinicavet.service;

import br.com.clinicavet.dto.UsuarioRequest;
import br.com.clinicavet.dto.UsuarioResponse;
import br.com.clinicavet.exception.BusinessException;
import br.com.clinicavet.exception.ConflictException;
import br.com.clinicavet.exception.NotFoundException;
import br.com.clinicavet.mapper.UsuarioMapper;
import br.com.clinicavet.model.Perfil;
import br.com.clinicavet.model.Tutor;
import br.com.clinicavet.model.Usuario;
import br.com.clinicavet.repository.PerfilRepository;
import br.com.clinicavet.repository.TutorRepository;
import br.com.clinicavet.repository.UsuarioRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class UsuarioService {

    private final UsuarioRepository usuarioRepository;
    private final PerfilRepository perfilRepository;
    private final TutorRepository tutorRepository;
    private final PasswordEncoder passwordEncoder;
    private final UsuarioMapper mapper;
    private final LogService logService;

    @Transactional(readOnly = true)
    public List<UsuarioResponse> listar() {
        return usuarioRepository.findAll().stream().map(mapper::toResponse).toList();
    }

    @Transactional
    public UsuarioResponse criar(UsuarioRequest req) {
        String email = req.email().trim().toLowerCase();
        if (req.senha() == null || req.senha().length() < 6) throw new BusinessException("Informe uma senha com pelo menos 6 caracteres.");
        if (usuarioRepository.existsByEmail(email)) throw new ConflictException("JÃ¡ existe um usuÃ¡rio com este e-mail.");

        Usuario u = Usuario.builder().nome(req.nome().trim()).email(email).senha(passwordEncoder.encode(req.senha()))
                .fotoUrl(req.fotoUrl()).perfil(perfil(req.perfil())).tutor(tutor(req.tutorId()))
                .ativo(req.ativo() == null || req.ativo()).build();
        u = usuarioRepository.save(u);
        logService.usuario(u.getId(), "CRIACAO", "UsuÃ¡rio criado: " + u.getEmail() + " (" + u.getPerfil().getNome() + ")", null);
        return mapper.toResponse(u);
    }

    @Transactional
    public UsuarioResponse atualizar(Long id, UsuarioRequest req) {
        Usuario u = usuarioRepository.findById(id).orElseThrow(() -> new NotFoundException("UsuÃ¡rio nÃ£o encontrado."));
        u.setNome(req.nome().trim());
        u.setFotoUrl(req.fotoUrl());
        u.setPerfil(perfil(req.perfil()));
        u.setTutor(tutor(req.tutorId()));
        if (req.ativo() != null) u.setAtivo(req.ativo());
        if (req.senha() != null && !req.senha().isBlank()) u.setSenha(passwordEncoder.encode(req.senha()));
        u = usuarioRepository.save(u);
        logService.usuario(id, "ATUALIZACAO", "UsuÃ¡rio atualizado: " + u.getEmail() + " (perfil " + u.getPerfil().getNome() + ", ativo=" + u.getAtivo() + ")", null);
        return mapper.toResponse(u);
    }

    private Perfil perfil(String nome) {
        return perfilRepository.findByNome(nome.trim().toUpperCase()).orElseThrow(() -> new BusinessException("Perfil invÃ¡lido."));
    }

    private Tutor tutor(Long id) {
        if (id == null) return null;
        return tutorRepository.findByIdAndAtivoTrue(id).orElseThrow(() -> new NotFoundException("Tutor vinculado nÃ£o encontrado."));
    }
}