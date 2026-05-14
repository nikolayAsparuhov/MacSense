# Mapa de bolhas

Os círculos interativos na aba Tamanho do Armazenamento. Cada bolha representa uma pasta; a área é proporcional ao tamanho recursivo da pasta.

## Detalhes

Como ler:

- **Círculo maior = pasta maior.** Área bidimensional, não raio — uma pasta com o dobro do tamanho tem aproximadamente o dobro da área visível.
- **Clique numa bolha** para entrar nessa pasta. O mapa de bolhas à direita e o caminho de migalhas no topo se atualizam.
- **Trilha de seleção** na barra lateral à esquerda permite alternar itens para a Lixeira. Alternar aqui seleciona pastas inteiras de uma vez.

Irmãos pequenos são agrupados numa bolha **"Outros itens"** para a visualização permanecer legível. Clicar nela expande a lista da barra lateral para mostrar cada entrada.

O layout das bolhas é recalculado sempre que o caminho muda — sem animação entre layouts, para a navegação ficar ágil.
