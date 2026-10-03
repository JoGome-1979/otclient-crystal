# Validação executada

- Presets reconhecidos pelo CMake do Windows e do Ubuntu WSL.
- Configuração do controlador Windows concluída; comandos de build verificados com Ninja em modo simulação.
- Configuração dos controladores linux, android e linux-portable concluída no WSL; comandos verificados em modo simulação.
- Sintaxe Bash de build-portable.sh aprovada por bash -n.
- Teste de integração do controlador Linux concluído com um projeto C++ mínimo isolado em work/build-controller-fixture. GCC 13 produziu um ELF x86-64; o controlador copiou recursos e binário para as saídas client/updater. As comparações cmp confirmaram que o binário exportado e o preservado em files/ eram iguais ao resultado compilado.
- O fluxo Android informa a ausência de Java antes de criar data.zip ou executar o Gradle.
- O fluxo portátil informa a ausência de Docker antes de criar uma imagem.

Nenhum binário do cliente real ou APK foi compilado. A imagem Docker portátil, os builds Android/Windows completos e a compatibilidade gráfica entre distribuições continuam sem validação neste ambiente. Java, SDK, Docker e o keystore correto precisam estar disponíveis para esses fluxos.

Nenhum arquivo em D:\otclient-main foi alterado por esta análise. A VPS não foi modificada e não houve instalação de componentes no WSL. Arquivos de controlador, caches de validação e fixtures foram criados apenas nas pastas outputs/ e work/ desta conversa.
