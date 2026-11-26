package br.com.clinicavet.service;

import br.com.clinicavet.dto.PetRequest;
import br.com.clinicavet.dto.PetResponse;
import br.com.clinicavet.exception.NotFoundException;
import br.com.clinicavet.mapper.PetMapper;
import br.com.clinicavet.model.Pet;
import br.com.clinicavet.model.Tutor;
import br.com.clinicavet.repository.PetRepository;
import br.com.clinicavet.repository.TutorRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PetServiceTest {

    @Mock PetRepository petRepository;
    @Mock TutorRepository tutorRepository;
    @Mock LogService logService;
    private PetService service;

    @BeforeEach
    void setUp() {
        service = new PetService(petRepository, tutorRepository, new PetMapper(), logService);
    }

    @Test
    void criar_semTutorDisponivel_lancaNotFoundException() {
        when(tutorRepository.findByIdAndAtivoTrue(99L)).thenReturn(Optional.empty());
        assertThrows(NotFoundException.class, () -> service.criar(new PetRequest("Rex", "CÃ£o", null, null, 99L)));
        verify(petRepository, never()).save(any());
    }

    @Test
    void criar_comTutorDisponivel_associaPetAoTutorEGravaLog() {
        Tutor tutor = Tutor.builder().id(5L).nome("Carlos").build();
        when(tutorRepository.findByIdAndAtivoTrue(5L)).thenReturn(Optional.of(tutor));
        when(petRepository.save(any(Pet.class))).thenAnswer(inv -> {
            Pet p = inv.getArgument(0);
            p.setId(10L);
            return p;
        });

        PetResponse resp = service.criar(new PetRequest("Rex", "CÃ£o", "SRD", null, 5L));

        assertEquals(5L, resp.tutorId());
        assertEquals("Carlos", resp.tutorNome());
        verify(logService).pet(eq(10L), eq("CRIACAO"), anyString());
    }
}