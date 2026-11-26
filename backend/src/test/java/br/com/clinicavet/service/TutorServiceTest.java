package br.com.clinicavet.service;

import br.com.clinicavet.dto.TutorRequest;
import br.com.clinicavet.dto.TutorResponse;
import br.com.clinicavet.exception.BusinessException;
import br.com.clinicavet.exception.ConflictException;
import br.com.clinicavet.mapper.TutorMapper;
import br.com.clinicavet.model.Tutor;
import br.com.clinicavet.repository.PetRepository;
import br.com.clinicavet.repository.TutorRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class TutorServiceTest {

    @Mock TutorRepository tutorRepository;
    @Mock PetRepository petRepository;
    @Mock LogService logService;

    private final CryptoService crypto = new CryptoService("segredo-aes-teste", "segredo-hmac-teste");
    private TutorService service;

    @BeforeEach
    void setUp() {
        service = new TutorService(tutorRepository, petRepository, crypto, new TutorMapper(crypto), logService);
    }

    private TutorRequest request(String cpf) {
        return new TutorRequest("Mariana Souza", cpf, "(71) 99811-2233", "mariana@email.com", "Salvador/BA");
    }

    @Test
    void criar_comCpfInvalido_lancaBusinessException() {
        assertThrows(BusinessException.class, () -> service.criar(request("123.456.789-00")));
        verify(tutorRepository, never()).save(any());
    }

    @Test
    void criar_comCpfDuplicado_lancaConflictException() {
        when(tutorRepository.existsByCpfHash(anyString())).thenReturn(true);
        assertThrows(ConflictException.class, () -> service.criar(request("529.982.247-25")));
        verify(tutorRepository, never()).save(any());
    }

    @Test
    void criar_comSucesso_criptografaCpfEMascaraNaResposta() {
        when(tutorRepository.existsByCpfHash(anyString())).thenReturn(false);
        when(tutorRepository.save(any(Tutor.class))).thenAnswer(inv -> {
            Tutor t = inv.getArgument(0);
            t.setId(1L);
            return t;
        });
        when(petRepository.countByTutorIdAndAtivoTrue(1L)).thenReturn(0L);

        TutorResponse resp = service.criar(request("529.982.247-25"));

        ArgumentCaptor<Tutor> captor = ArgumentCaptor.forClass(Tutor.class);
        verify(tutorRepository).save(captor.capture());
        Tutor salvo = captor.getValue();
        assertNotEquals("52998224725", salvo.getCpfCriptografado());
        assertEquals("52998224725", crypto.decifrar(salvo.getCpfCriptografado()));
        assertEquals(crypto.hash("52998224725"), salvo.getCpfHash());
        assertEquals("***.982.247-**", resp.cpfMascarado());
        verify(logService).tutor(eq(1L), eq("CRIACAO"), anyString());
    }

    @Test
    void atualizar_semEnviarCpf_mantemCpfEGravaLog() {
        Tutor existente = Tutor.builder().id(1L).nome("Antigo").telefone("1").email("a@a.com")
                .cpfCriptografado(crypto.cifrar("52998224725")).cpfHash(crypto.hash("52998224725")).build();
        when(tutorRepository.findByIdAndAtivoTrue(1L)).thenReturn(Optional.of(existente));
        when(tutorRepository.save(any(Tutor.class))).thenAnswer(inv -> inv.getArgument(0));
        when(petRepository.countByTutorIdAndAtivoTrue(1L)).thenReturn(1L);

        TutorResponse resp = service.atualizar(1L, request(null));

        assertEquals("Mariana Souza", resp.nome());
        assertEquals(crypto.hash("52998224725"), existente.getCpfHash());
        verify(logService).tutor(eq(1L), eq("ATUALIZACAO"), contains("nome"));
    }

    @Test
    void inativar_tutorComPetsAtivos_lancaBusinessException() {
        Tutor t = Tutor.builder().id(1L).nome("X").build();
        when(tutorRepository.findByIdAndAtivoTrue(1L)).thenReturn(Optional.of(t));
        when(petRepository.countByTutorIdAndAtivoTrue(1L)).thenReturn(2L);
        assertThrows(BusinessException.class, () -> service.inativar(1L));
        verify(tutorRepository, never()).save(any());
    }

    @Test
    void listar_comBusca_usaConsultaDeBusca() {
        when(tutorRepository.buscar(eq("mar"), anyString())).thenReturn(List.of());
        assertTrue(service.listar("mar").isEmpty());
        verify(tutorRepository).buscar(eq("mar"), anyString());
        verify(tutorRepository, never()).findByAtivoTrueOrderByNomeAsc();
    }
}