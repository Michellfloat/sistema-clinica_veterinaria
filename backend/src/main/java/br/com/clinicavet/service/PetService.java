package br.com.clinicavet.service;

import br.com.clinicavet.dto.PetRequest;
import br.com.clinicavet.dto.PetResponse;
import br.com.clinicavet.exception.NotFoundException;
import br.com.clinicavet.mapper.PetMapper;
import br.com.clinicavet.model.Pet;
import br.com.clinicavet.model.Tutor;
import br.com.clinicavet.model.Usuario;
import br.com.clinicavet.repository.PetRepository;
import br.com.clinicavet.repository.TutorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class PetService {

    private final PetRepository petRepository;
    private final TutorRepository tutorRepository;
    private final PetMapper mapper;
    private final LogService logService;

    @Transactional(readOnly = true)
    public List<PetResponse> listar(String busca, Usuario usuario) {
        List<Pet> pets;
        if (somenteProprios(usuario)) {
            pets = usuario.getTutor() == null ? List.of() : petRepository.listarPorTutor(usuario.getTutor().getId());
        } else if (busca == null || busca.isBlank()) {
            pets = petRepository.listarAtivos();
        } else {
            pets = petRepository.buscar(busca.trim());
        }
        return pets.stream().map(mapper::toResponse).toList();
    }

    @Transactional
    public PetResponse criar(PetRequest req) {
        Tutor tutor = tutorDisponivel(req.tutorId());
        Pet pet = Pet.builder().nome(req.nome().trim()).especie(req.especie().trim()).raca(req.raca())
                .dataNascimento(req.dataNascimento()).tutor(tutor).build();
        pet = petRepository.save(pet);
        logService.pet(pet.getId(), "CRIACAO", "Pet cadastrado: " + pet.getNome() + " (tutor: " + tutor.getNome() + ")");
        return mapper.toResponse(pet);
    }

    @Transactional
    public PetResponse atualizar(Long id, PetRequest req) {
        Pet pet = obter(id);
        Tutor tutor = tutorDisponivel(req.tutorId());
        String detalhe = "Pet atualizado: " + pet.getNome() + " -> " + req.nome().trim();
        if (!pet.getTutor().getId().equals(tutor.getId())) detalhe += "; tutor: " + pet.getTutor().getNome() + " -> " + tutor.getNome();
        pet.setNome(req.nome().trim());
        pet.setEspecie(req.especie().trim());
        pet.setRaca(req.raca());
        pet.setDataNascimento(req.dataNascimento());
        pet.setTutor(tutor);
        pet = petRepository.save(pet);
        logService.pet(id, "ATUALIZACAO", detalhe);
        return mapper.toResponse(pet);
    }

    @Transactional
    public void inativar(Long id) {
        Pet pet = obter(id);
        pet.setAtivo(false);
        petRepository.save(pet);
        logService.pet(id, "REMOCAO", "Pet inativado: " + pet.getNome());
    }

    /** Regra: todo pet deve ser associado a um tutor disponÃ­vel (existente e ativo). */
    private Tutor tutorDisponivel(Long tutorId) {
        return tutorRepository.findByIdAndAtivoTrue(tutorId)
                .orElseThrow(() -> new NotFoundException("Tutor indisponÃ­vel. Associe o pet a um tutor cadastrado."));
    }

    private Pet obter(Long id) {
        return petRepository.buscarAtivoPorId(id).orElseThrow(() -> new NotFoundException("Pet nÃ£o encontrado."));
    }

    static boolean somenteProprios(Usuario usuario) {
        if (usuario == null) return false;
        String p = usuario.getPerfil().getNome();
        return p.equals("TUTOR") || p.equals("PET");
    }
}