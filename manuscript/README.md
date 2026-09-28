# Author accepted manuscript

Seidel, H.-P., Standfuss, J. & Weinert, T. (2026). *TorchRef: An open-source PyTorch
Framework for Crystallographic Refinement.* Journal of Applied Crystallography, accepted.
<!-- TODO: link to the published article on journals.iucr.org once available -->

This is the author accepted manuscript: the peer-reviewed version accepted for publication,
without the journal's technical editing and typesetting. It is deposited under the IUCr
green open-access policy and licensed CC BY 4.0. Please cite the published article.

| File | Contents |
|------|----------|
| `torchref_accepted_manuscript.pdf` | Main text |
| `supplementary_accepted_manuscript.pdf` | Supplementary Methods |
| `torchref.tex`, `supplementary.tex` | LaTeX source |
| `torchref.bib` | Bibliography database |
| `torchref.bbl`, `supplementary.bbl` | Processed bibliographies, so the source builds without BibTeX |
| `fig*.png`, `figS*.png` | Figures as included in the manuscript |
| `iucrjournals.cls` | IUCr journals LaTeX class (CC0) |

To build (needs a TeX Live installation with the `harvard` package):

```bash
pdflatex torchref && pdflatex torchref
pdflatex supplementary && pdflatex supplementary
```

To regenerate the bibliography instead of using the `.bbl` files, also fetch `iucr.bst` from the
IUCr LaTeX template and run `bibtex` between the two `pdflatex` passes.
