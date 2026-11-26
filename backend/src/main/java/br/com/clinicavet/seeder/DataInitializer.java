package br.com.clinicavet.seeder;

import br.com.clinicavet.dto.*;
import br.com.clinicavet.model.Tutor;
import br.com.clinicavet.repository.TutorRepository;
import br.com.clinicavet.repository.UsuarioRepository;
import br.com.clinicavet.service.AgendamentoService;
import br.com.clinicavet.service.PetService;
import br.com.clinicavet.service.TutorService;
import br.com.clinicavet.service.UsuarioService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

/** Popula o banco com dados de exemplo (mÃ­nimo de 3 registros por tabela). SÃ³ roda se o banco estiver vazio. */
@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "app.seed.enabled", havingValue = "true")
public class DataInitializer implements ApplicationRunner {

    private final TutorService tutorService;
    private final PetService petService;
    private final AgendamentoService agendamentoService;
    private final UsuarioService usuarioService;
    private final TutorRepository tutorRepository;
    private final UsuarioRepository usuarioRepository;

    @Override
    public void run(ApplicationArguments args) {
        if (tutorRepository.count() > 0 || usuarioRepository.count() > 0) {
            log.info("Seed ignorado: o banco jÃ¡ possui dados.");
            return;
        }
        log.info("Populando banco com dados de exemplo...");

        Long t1 = tutorService.criar(new TutorRequest("Mariana Souza", "529.982.247-25", "(71) 99811-2233", "mariana.souza@email.com", "Rua das AcÃ¡cias, 120 - Pituba, Salvador/BA")).id();
        Long t2 = tutorService.criar(new TutorRequest("Carlos Eduardo Lima", "111.444.777-35", "(71) 98822-4455", "carlos.lima@email.com", "Av. OceÃ¢nica, 900 - Barra, Salvador/BA")).id();
        Long t3 = tutorService.criar(new TutorRequest("Fernanda Oliveira", "935.411.347-80", "(71) 99700-1010", "fernanda.o@email.com", "Rua da Paz, 45 - Rio Vermelho, Salvador/BA")).id();

        Long p1 = petService.criar(new PetRequest("Thor", "CÃ£o", "Golden Retriever", LocalDate.of(2020, 3, 14), t1)).id();
        Long p2 = petService.criar(new PetRequest("Mel", "Gato", "SiamÃªs", LocalDate.of(2021, 7, 2), t2)).id();
        Long p3 = petService.criar(new PetRequest("Bob", "CÃ£o", "Vira-lata", LocalDate.of(2019, 11, 20), t3)).id();
        petService.criar(new PetRequest("Luna", "Gato", "Persa", LocalDate.of(2022, 1, 9), t1));

        LocalDate amanha = LocalDate.now().plusDays(1);
        agendamentoService.criar(new AgendamentoRequest(LocalDateTime.of(amanha, LocalTime.of(9, 0)), "Vacina antirrÃ¡bica", "Trazer carteirinha", p1), null);
        agendamentoService.criar(new AgendamentoRequest(LocalDateTime.of(amanha, LocalTime.of(14, 30)), "Consulta de rotina", null, p2), null);
        agendamentoService.criar(new AgendamentoRequest(LocalDateTime.of(amanha.plusDays(2), LocalTime.of(10, 0)), "Retorno pÃ³s-cirÃºrgico", "Jejum de 8h", p3), null);
        agendamentoService.criar(new AgendamentoRequest(LocalDateTime.of(amanha.plusDays(5), LocalTime.of(16, 0)), "Banho e tosa", null, p1), null);

        usuarioService.criar(new UsuarioRequest("Administrador Geral", "admin@clinicavet.com", "Admin@123", "ADMIN", null, null, true));
        usuarioService.criar(new UsuarioRequest("Ana Atendente", "atendente@clinicavet.com", "Atend@123", "USUARIO", null, null, true));
        usuarioService.criar(new UsuarioRequest("Mariana Souza", "tutor@clinicavet.com", "Tutor@123", "TUTOR", null, t1, true));
        usuarioService.criar(new UsuarioRequest("Thor (Pet)", "pet@clinicavet.com", "Pet@1234", "PET", null, t1, true));

        log.info("Seed concluÃ­do. Login: admin@clinicavet.com / Admin@123");
    }
}