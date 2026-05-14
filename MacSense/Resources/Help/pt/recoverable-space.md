# Espaço recuperável

Total de bytes que o MacSense estima poder devolver entre todas as categorias do Smart Scan atual.

## Detalhes

O número no hero de Limpeza é a soma de:

- Lixo do sistema
- Cache do usuário
- Lixeiras
- Espaço purgável (snapshots locais TM + arquivos liberáveis do iCloud)
- Caches de desenvolvimento

Um escaneamento não é destrutivo — nada é removido até você clicar em Limpar numa categoria. A estimativa usa o tamanho alocado em disco, a mesma medida que o macOS mostra em "Obter Informações", então os bytes que você vê são os bytes que verá liberados.

Os números diminuem ligeiramente com o tempo porque o macOS rotaciona logs, libera caches e escreve novos arquivos. Re-executar Smart Scan atualiza a estimativa.
