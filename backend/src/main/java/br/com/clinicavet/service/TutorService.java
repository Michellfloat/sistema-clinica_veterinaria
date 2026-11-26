package br.com.clinicavet.service;

import br.com.clinicavet.dto.TutorRequest;
import br.com.clinicavet.dto.TutorResponse;
import br.com.clinicavet.exception.BusinessException;
import br.com.clinicavet.exception.ConflictException;
import br.com.clinicavet.exception.NotFoundException;
import br.com.clinicavet.mapper.TutorMapper;
import br.com.clinicavet.model.Tutor;
import br.com.clinicavet.repository.PetRepository;
import br.com.clinicavet.repository.TutorRepository;
import br.com.clinicavet.util.CpfUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class TutorService {

    private final TutorRepository tutorRepository;
    private final PetRepository petRepository;
    private final CryptoService crypto;
    private final TutorMapper mapper;
    private final LogService logService;

    /** Sem termo: lista todos. Com termo: filtra por nome, e-mail, telefone ou CPF (busca exata). */
    @Transactional(readOnly = true)
    public List<TutorResponse> listar(String busca) {
        List<Tutor> tutores;
        if (busca == null || busca.isBlank()) {
            tutores = tutorRepository.findByAtivoTrueOrderByNomeAsc();
        } else {
            String termo = busca.trim();
            tutores = tutorRepository.buscar(termo, crypto.hash(CpfUtil.limpar(termo)));
        }
        return tutores.stream().map(this::paraResponse).toList();
    }

    @Transactional(readOnly = true)
    public TutorResponse buscarPorId(Long id) {
        return paraResponse(obter(id));
    }

    @Transactional
    public TutorResponse criar(TutorRequest req) {
        String cpf = CpfUtil.limpar(req.cpf());
        if (!CpfUtil.valido(cpf)) throw new BusinessException("CPF invÃ¡lido.");
        String hash = crypto.hash(cpf);
        if (tutorRepository.existsByCpfHash(hash)) throw new ConflictException("JÃ¡ existe um tutor cadastrado com este CPF.");

        Tutor tutor = Tutor.builder()
                .nome(req.nome().trim()).telefone(req.telefone().trim()).email(req.email().trim().toLowerCase())
                .endereco(req.endereco()).cpfCriptografado(crypto.cifrar(cpf)).cpfHash(hash).build();
        tutor = tutorRepository.save(tutor);
        logService.tutor(tutor.getId(), "CRIACAO", "Tutor cadastrado: " + tutor.getNome());
        return paraResponse(tutor);
    }

    @Transactional
    public TutorResponse atualizar(Long id, TutorRequest req) {
        Tutor tutor = obter(id);
        List<String> alteracoes = new ArrayList<>();

        if (!tutor.getNome().equals(req.nome().trim())) alteracoes.add("nome '" + tutor.getNome() + "' -> '" + req.nome().trim() + "'");
        if (!tutor.getTelefone().equals(req.telefone().trim())) alteracoes.add("telefone '" + tutor.getTelefone() + "' -> '" + req.telefone().trim() + "'");
        if (!tutor.getEmail().equalsIgnoreCase(req.email().trim())) alteracoes.add("e-mail '" + tutor.getEmail() + "' -> '" + req.email().trim().toLowerCase() + "'");
        if (req.endereco() != null && !req.endereco().equals(tutor.getEndereco())) alteracoes.add("endereÃ§o alterado");

        tutor.setNome(req.nome().trim());
        tutor.setTelefone(req.telefone().trim());
        tutor.setEmail(req.email().trim().toLowerCase());
        tutor.setEndereco(req.endereco());

        if (req.cpf() != null && !req.cpf().isBlank()) {
            String cpf = CpfUtil.limpar(req.cpf());
            if (!CpfUtil.valido(cpf)) throw new BusinessException("CPF invÃ¡lido.");
            String hash = crypto.hash(cpf);
            if (!hash.equals(tutor.getCpfHash())) {
                if (tutorRepository.existsByCpfHashAndIdNot(hash, id)) throw new ConflictException("JÃ¡ existe um tutor cadastrado com este CPF.");
                tutor.setCpfHash(hash);
                tutor.setCpfCriptografado(crypto.cifrar(cpf));
                alteracoes.add("CPF atualizado"); // o valor nunca Ã© registrado no log
            }
        }

        tutor = tutorRepository.save(tutor);
        logService.tutor(id, "ATUALIZACAO", alteracoes.isEmpty() ? "Cadastro salvo sem alteraÃ§Ãµes" : "Alterado: " + String.join("; ", alteracoes));
        return paraResponse(tutor);
    }

    @Transactional
    public void inativar(Long id) {
        Tutor tutor = obter(id);
        if (petRepository.countByTutorIdAndAtivoTrue(id) > 0) {
            throw new BusinessException("NÃ£o Ã© possÃ­vel remover um tutor que possui pets ativos. Transfira ou remova os pets primeiro.");
        }
        tutor.setAtivo(false);
        tutorRepository.save(tutor);
        logService.tutor(id, "REMOCAO", "Tutor inativado: " + tutor.getNome());
    }

    private Tutor obter(Long id) {
        return tutorRepository.findByIdAndAtivoTrue(id).orElseThrow(() -> new NotFoundException("Tutor nÃ£o encontrado."));
    }

    private TutorResponse paraResponse(Tutor t) {
        return mapper.toResponse(t, petRepository.countByTutorIdAndAtivoTrue(t.getId()));
    }
}