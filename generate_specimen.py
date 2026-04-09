#!/usr/bin/env python3
"""
generate_specimen.py — Comprehensive Specimen Generator for GrugBot420
═══════════════════════════════════════════════════════════════════════
GRUG: Build the fattest, most detailed specimen file ever seen.
Academic: Programmatically constructs a complete v2.1 specimen covering
all 17 state categories with 200+ nodes across 12 subject domains,
custom verb classes, orchestration rules, inhibitions, attachments,
message history, trajectory state, temporal coherence, and more.

Output: grugbot420_comprehensive.specimen.gz (gzip-compressed JSON)
"""

import json
import gzip
import hashlib
import time
import struct
import os
import random

random.seed(42)  # reproducible specimen

# ═══════════════════════════════════════════════════════════════════════
# HELPER: Replicate Julia's hash() for words_to_signal
# ═══════════════════════════════════════════════════════════════════════
# Julia's hash() is NOT portable to Python — it uses internal SipHash.
# For the specimen, signal vectors are RESTORED verbatim from JSON,
# so we just need CONSISTENT float vectors per pattern string.
# We'll use a deterministic hash that produces [0.0, 1.0] floats.

def words_to_signal(text):
    """Produce a signal vector from pattern text (one float per token)."""
    tokens = text.lower().strip().split()
    signal = []
    for tok in tokens:
        # Use SHA-256 truncated to 8 bytes, interpreted as uint64, divided by max
        h = hashlib.sha256(tok.encode('utf-8')).digest()[:8]
        val = struct.unpack('<Q', h)[0]
        signal.append(val / ((1 << 64) - 1))
    return signal

def hopfield_key(pattern):
    """Compute a hopfield hash key for a pattern (stored as string of uint64)."""
    h = hashlib.sha256(pattern.lower().strip().encode('utf-8')).digest()[:8]
    return str(struct.unpack('<Q', h)[0])

# ═══════════════════════════════════════════════════════════════════════
# NODE FACTORY
# ═══════════════════════════════════════════════════════════════════════

NODE_COUNTER = [0]

def make_node(pattern, action_packet, json_data=None, drop_table=None,
              is_image_node=False, strength=None, relational_patterns=None,
              required_relations=None, relation_weights=None,
              neighbor_ids=None, is_grave=False, grave_reason="",
              response_times=None):
    """Create a node dict matching the exact specimen format."""
    NODE_COUNTER[0] += 1
    nid = f"N-{NODE_COUNTER[0]:04d}"
    
    if json_data is None:
        json_data = {}
    if drop_table is None:
        drop_table = []
    if relational_patterns is None:
        relational_patterns = []
    if required_relations is None:
        required_relations = []
    if relation_weights is None:
        relation_weights = {}
    if neighbor_ids is None:
        neighbor_ids = []
    if response_times is None:
        response_times = [round(random.uniform(0.05, 2.0), 4) for _ in range(random.randint(1, 8))]
    if strength is None:
        strength = round(random.uniform(0.5, 9.5), 2)
    
    sig = words_to_signal(pattern) if not is_image_node else []
    
    return {
        "id": nid,
        "pattern": pattern,
        "signal": sig,
        "action_packet": action_packet,
        "json_data": json_data,
        "drop_table": drop_table,
        "throttle": round(random.uniform(0.3, 0.8), 2),
        "relational_patterns": relational_patterns,
        "required_relations": required_relations,
        "relation_weights": relation_weights,
        "strength": strength,
        "is_image_node": is_image_node,
        "neighbor_ids": neighbor_ids,
        "is_unlinkable": len(neighbor_ids) >= 4,
        "is_grave": is_grave,
        "grave_reason": grave_reason,
        "response_times": response_times,
        "ledger_last_cleared": time.time() - random.uniform(0, 86400),
        "hopfield_key": hopfield_key(pattern)
    }


# ═══════════════════════════════════════════════════════════════════════
# DOMAIN NODE DEFINITIONS
# ═══════════════════════════════════════════════════════════════════════

ALL_NODES = []

# ─── DOMAIN 1: COMPUTER SCIENCE ──────────────────────────────────────
cs_nodes = [
    make_node(
        "algorithm sorting quicksort mergesort heapsort",
        "analyze[dont oversimplify, dont skip time complexity]^5 | explain[dont use pseudocode only]^3 | reason^2",
        {"system_prompt": "Expert algorithm analysis mode. Compare time and space complexity. Discuss stability and in-place properties.",
         "required_relations": ["uses", "improves"],
         "relation_weights": {"uses": 2.0, "improves": 3.0}},
        ["never claim bubble sort is efficient", "never confuse stable vs unstable"]
    ),
    make_node(
        "data structure tree binary search balanced avl red black",
        "explain[dont ignore edge cases]^4 | analyze[dont skip rotations]^3 | describe^2",
        {"system_prompt": "Binary tree specialist. Cover AVL rotations, red-black properties, B-tree variants.",
         "required_relations": ["contains", "balances"],
         "relation_weights": {"contains": 1.5, "balances": 2.5}}
    ),
    make_node(
        "graph theory dijkstra shortest path bfs dfs traversal",
        "reason[dont confuse directed and undirected]^5 | analyze^3 | explain^2",
        {"system_prompt": "Graph algorithm engine. Dijkstra, Bellman-Ford, Floyd-Warshall. Negative edge awareness."}
    ),
    make_node(
        "recursion base case stack overflow fibonacci factorial",
        "explain[dont skip base case, dont ignore stack depth]^4 | reason^3 | clarify^1",
        {"system_prompt": "Recursion pedagogy mode. Always start with base case. Discuss tail-call optimization."}
    ),
    make_node(
        "object oriented programming class inheritance polymorphism encapsulation",
        "explain[dont conflate composition and inheritance]^4 | describe^3 | elaborate^2",
        {"system_prompt": "OOP fundamentals instructor. SOLID principles. Favor composition over inheritance."}
    ),
    make_node(
        "functional programming lambda higher order map filter reduce monad",
        "explain[dont oversimplify monads]^5 | reason[dont ignore side effects]^3 | analyze^2",
        {"system_prompt": "Functional programming specialist. Pure functions, immutability, referential transparency."}
    ),
    make_node(
        "database sql relational normalization index query optimization",
        "analyze[dont ignore query plans]^4 | explain[dont skip normalization forms]^3 | reason^2",
        {"system_prompt": "Database systems expert. ACID, CAP theorem, B+ tree indexes, query optimization."}
    ),
    make_node(
        "operating system kernel process thread memory management virtual",
        "explain[dont conflate process and thread]^4 | analyze^3 | describe^2",
        {"system_prompt": "OS internals mode. Scheduling algorithms, virtual memory, page tables, context switching."}
    ),
    make_node(
        "network tcp ip udp http https protocol socket packet routing",
        "explain[dont confuse TCP and UDP guarantees]^4 | describe^3 | clarify^2",
        {"system_prompt": "Network protocol analyst. OSI model, TCP handshake, DNS resolution, TLS/SSL."}
    ),
    make_node(
        "cryptography encryption hash sha aes rsa public key private key",
        "explain[dont oversimplify key exchange]^5 | analyze[dont skip attack vectors]^3 | warn^1",
        {"system_prompt": "Cryptography specialist. Symmetric vs asymmetric, hash collisions, Diffie-Hellman, zero-knowledge proofs."}
    ),
    make_node(
        "machine learning neural network gradient descent backpropagation loss function",
        "analyze[dont hallucinate results, dont skip regularization]^5 | explain^3 | reason^2",
        {"system_prompt": "ML engine active. Discuss bias-variance tradeoff, overfitting, learning rate schedules."}
    ),
    make_node(
        "compiler lexer parser ast syntax semantics code generation optimization",
        "explain[dont skip parsing phases]^4 | analyze^3 | describe^2",
        {"system_prompt": "Compiler construction mode. Lexical analysis, context-free grammars, SSA form, register allocation."}
    ),
    make_node(
        "concurrency parallel mutex semaphore deadlock race condition atomic",
        "warn[dont minimize deadlock risk]^4 | explain^3 | analyze^2",
        {"system_prompt": "Concurrency safety mode. Dining philosophers, lock ordering, CAS operations, memory barriers."},
        ["never suggest busy-waiting as primary strategy"]
    ),
    make_node(
        "distributed systems consensus raft paxos replication partition tolerance",
        "analyze[dont ignore network partitions]^5 | explain^3 | reason^2",
        {"system_prompt": "Distributed systems analyst. CAP theorem implications, eventual consistency, vector clocks."}
    ),
    make_node(
        "git version control branch merge rebase commit repository",
        "explain[dont confuse merge and rebase]^3 | describe^2 | clarify^1",
        {"system_prompt": "Git workflow guide. Feature branches, interactive rebase, conflict resolution, bisect."}
    ),
    make_node(
        "regex regular expression pattern match capture group lookahead",
        "explain[dont write unreadable patterns]^3 | describe^2 | clarify^1",
        {"system_prompt": "Regex craftsman. Named groups, lookahead/lookbehind, non-greedy quantifiers, catastrophic backtracking."}
    ),
    make_node(
        "complexity theory big o notation polynomial exponential np complete",
        "reason[dont confuse P and NP]^5 | analyze^4 | explain^2",
        {"system_prompt": "Computational complexity mode. P vs NP, reduction proofs, Cook-Levin theorem, approximation algorithms."}
    ),
    make_node(
        "api rest graphql endpoint authentication rate limit middleware",
        "explain[dont ignore auth]^3 | describe^2 | clarify^1",
        {"system_prompt": "API design mode. RESTful constraints, GraphQL schemas, OAuth2, JWT, rate limiting strategies."}
    ),
]
ALL_NODES.extend(cs_nodes)

# ─── DOMAIN 2: MATHEMATICS ───────────────────────────────────────────
math_nodes = [
    make_node(
        "calculus derivative integral limit continuity differentiable",
        "analyze[dont skip epsilon-delta]^5 | explain^3 | reason^2",
        {"system_prompt": "Rigorous calculus mode. Epsilon-delta proofs, Riemann sums, fundamental theorem of calculus.",
         "required_relations": ["implies", "contradicts"],
         "relation_weights": {"implies": 2.0, "contradicts": 3.0}}
    ),
    make_node(
        "linear algebra matrix vector eigenvalue determinant rank",
        "analyze[dont ignore dimensionality]^4 | explain^3 | calculate^2",
        {"system_prompt": "Linear algebra engine. Eigendecomposition, SVD, rank-nullity theorem, positive definiteness."}
    ),
    make_node(
        "probability statistics distribution normal bayesian hypothesis",
        "reason[dont confuse frequentist and bayesian]^5 | analyze^3 | calculate^2",
        {"system_prompt": "Statistical reasoning mode. Central limit theorem, p-values, confidence intervals, Bayesian updating."}
    ),
    make_node(
        "topology open set closed set compact connected homeomorphism",
        "reason[dont skip hausdorff condition]^5 | analyze^4 | explain^2",
        {"system_prompt": "Point-set topology mode. Compactness, connectedness, metric spaces, continuity."}
    ),
    make_node(
        "number theory prime factorization modular arithmetic fermat euler",
        "reason[dont assume all primes are odd]^4 | analyze^3 | calculate^2",
        {"system_prompt": "Number theory engine. Fermat's little theorem, Euler's totient, quadratic reciprocity, RSA foundations."}
    ),
    make_node(
        "abstract algebra group ring field homomorphism isomorphism",
        "reason[dont confuse group and ring axioms]^5 | analyze^4 | explain^2",
        {"system_prompt": "Abstract algebra mode. Lagrange's theorem, normal subgroups, quotient groups, Galois theory."}
    ),
    make_node(
        "differential equations ode pde boundary initial value laplace",
        "analyze[dont ignore initial conditions]^4 | calculate^3 | reason^2",
        {"system_prompt": "ODE/PDE solver mode. Separation of variables, Laplace transforms, existence and uniqueness theorems."}
    ),
    make_node(
        "set theory axiom zermelo fraenkel cardinal ordinal cantor infinity",
        "reason[dont confuse countable and uncountable]^5 | analyze^3 | explain^2",
        {"system_prompt": "Set theory foundations. ZFC axioms, Cantor's diagonal argument, continuum hypothesis."}
    ),
    make_node(
        "geometry euclidean non-euclidean hyperbolic projective affine",
        "explain[dont conflate Euclidean and hyperbolic]^4 | describe^3 | reason^2",
        {"system_prompt": "Geometry mode. Parallel postulate, curvature, geodesics, projective duality."}
    ),
    make_node(
        "graph theory combinatorics counting permutation combination pigeonhole",
        "calculate[dont forget edge cases]^4 | reason^3 | explain^2",
        {"system_prompt": "Combinatorics engine. Inclusion-exclusion, generating functions, Burnside's lemma."}
    ),
    make_node(
        "category theory functor natural transformation adjunction monad morphism",
        "reason[dont handwave, dont skip diagrams]^5 | analyze^4 | explain^2",
        {"system_prompt": "Category theory mode. Universal properties, Yoneda lemma, limits and colimits, topoi."}
    ),
    make_node(
        "fourier analysis transform series frequency spectrum convolution",
        "analyze[dont confuse DFT and continuous FT]^4 | calculate^3 | explain^2",
        {"system_prompt": "Fourier analysis mode. Convergence conditions, Parseval's theorem, sampling theorem, spectral leakage."}
    ),
    make_node(
        "logic propositional predicate proof truth table tautology",
        "reason[dont confuse validity and soundness]^5 | analyze^3 | explain^2",
        {"system_prompt": "Formal logic engine. Natural deduction, resolution, Gödel's incompleteness theorems."}
    ),
]
ALL_NODES.extend(math_nodes)

# ─── DOMAIN 3: PHILOSOPHY ────────────────────────────────────────────
philo_nodes = [
    make_node(
        "epistemology knowledge belief justification truth skepticism",
        "reason[dont dismiss skepticism outright]^5 | ponder^4 | analyze^2",
        {"system_prompt": "Epistemological inquiry mode. Gettier problems, reliabilism, coherentism vs foundationalism."}
    ),
    make_node(
        "ethics morality deontology consequentialism virtue utilitarianism",
        "reason[dont strawman opposing views]^5 | ponder^4 | analyze^2",
        {"system_prompt": "Ethical reasoning mode. Trolley problems, categorical imperative, Rawls' veil of ignorance."}
    ),
    make_node(
        "metaphysics existence being identity substance causation free will",
        "ponder[dont claim certainty where none exists]^5 | reason^4 | analyze^2",
        {"system_prompt": "Metaphysical inquiry mode. Substance dualism, materialism, compatibilism, mereology."}
    ),
    make_node(
        "consciousness qualia hard problem mind body subjective experience",
        "ponder[dont dismiss the hard problem]^5 | reason^4 | analyze^3",
        {"system_prompt": "Philosophy of mind mode. Chinese room, Mary's room, functionalism, integrated information theory."}
    ),
    make_node(
        "existentialism absurdity freedom authenticity sartre camus kierkegaard",
        "ponder^4 | reason^3 | comfort^1",
        {"system_prompt": "Existentialist lens active. Radical freedom, bad faith, the absurd, leap of faith."}
    ),
    make_node(
        "logic paradox liar godel russell incompleteness self reference",
        "reason[dont dismiss paradoxes as tricks]^5 | analyze^4 | ponder^2",
        {"system_prompt": "Paradox analysis mode. Self-referential systems, dialetheism, paraconsistent logic."}
    ),
    make_node(
        "aesthetics beauty art sublime taste judgment perception",
        "ponder^4 | reason^3 | describe^2",
        {"system_prompt": "Aesthetics mode. Kantian sublime, Hegel's death of art, institutional theory, aesthetic experience."}
    ),
    make_node(
        "philosophy language meaning reference wittgenstein naming",
        "reason[dont conflate use and mention]^4 | analyze^3 | explain^2",
        {"system_prompt": "Philosophy of language mode. Private language argument, Kripke's naming, speech acts, meaning holism."}
    ),
    make_node(
        "political philosophy justice state power authority social contract",
        "reason[dont assume one framework superior]^4 | analyze^3 | ponder^2",
        {"system_prompt": "Political philosophy mode. Hobbes, Locke, Rousseau, Rawls, Nozick, anarchism."}
    ),
    make_node(
        "stoicism marcus aurelius epictetus seneca virtue control acceptance",
        "comfort^3 | reason^3 | ponder^2",
        {"system_prompt": "Stoic philosophy mode. Dichotomy of control, amor fati, memento mori, negative visualization."}
    ),
]
ALL_NODES.extend(philo_nodes)

# ─── DOMAIN 4: BIOLOGY ───────────────────────────────────────────────
bio_nodes = [
    make_node(
        "cell mitosis meiosis dna rna protein organelle membrane",
        "explain[dont confuse mitosis and meiosis]^4 | describe^3 | analyze^2",
        {"system_prompt": "Cell biology mode. Cell cycle checkpoints, organelle function, membrane transport."}
    ),
    make_node(
        "evolution natural selection adaptation speciation mutation genetic drift",
        "reason[dont misrepresent natural selection as teleological]^5 | explain^3 | analyze^2",
        {"system_prompt": "Evolutionary biology mode. Modern synthesis, punctuated equilibrium, kin selection, neutral theory."}
    ),
    make_node(
        "genetics gene allele chromosome heredity mendelian dominant recessive",
        "explain[dont oversimplify polygenic traits]^4 | analyze^3 | describe^2",
        {"system_prompt": "Genetics mode. Hardy-Weinberg equilibrium, epistasis, linkage disequilibrium, epigenetics."}
    ),
    make_node(
        "neuroscience brain neuron synapse neurotransmitter plasticity",
        "explain[dont oversimplify brain regions]^4 | analyze^3 | describe^2",
        {"system_prompt": "Neuroscience mode. Long-term potentiation, neural circuits, Hebbian learning, neurogenesis."}
    ),
    make_node(
        "ecology ecosystem food chain biodiversity symbiosis predator prey",
        "explain^3 | analyze^3 | describe^2",
        {"system_prompt": "Ecology mode. Trophic cascades, keystone species, island biogeography, succession dynamics."}
    ),
    make_node(
        "microbiology bacteria virus archaea fungi prokaryote antibiotic resistance",
        "explain[dont confuse bacteria and viruses]^4 | warn[dont downplay resistance]^3 | analyze^2",
        {"system_prompt": "Microbiology mode. Gram staining, viral replication cycles, horizontal gene transfer, biofilms."}
    ),
    make_node(
        "immunology immune system antibody antigen tcell bcell vaccine inflammation",
        "explain[dont oversimplify immune response]^4 | describe^3 | analyze^2",
        {"system_prompt": "Immunology mode. Innate vs adaptive immunity, MHC, cytokine storms, immunological memory."}
    ),
    make_node(
        "biochemistry enzyme substrate catalysis metabolism atp pathway krebs",
        "analyze[dont skip reaction mechanisms]^4 | explain^3 | calculate^2",
        {"system_prompt": "Biochemistry engine. Michaelis-Menten kinetics, allosteric regulation, glycolysis, electron transport chain."}
    ),
    make_node(
        "taxonomy classification kingdom phylum species linnaeus phylogenetics",
        "explain^3 | describe^3 | clarify^2",
        {"system_prompt": "Taxonomy mode. Cladistics, molecular phylogenetics, three-domain system, binomial nomenclature."}
    ),
    make_node(
        "photosynthesis chloroplast light reaction calvin cycle carbon fixation",
        "explain^4 | analyze^3 | describe^2",
        {"system_prompt": "Photosynthesis mode. Z-scheme, photosystems I & II, C3/C4/CAM pathways, photorespiration."}
    ),
]
ALL_NODES.extend(bio_nodes)

# ─── DOMAIN 5: PHYSICS ───────────────────────────────────────────────
physics_nodes = [
    make_node(
        "quantum mechanics wave function superposition entanglement measurement collapse",
        "reason[dont claim consciousness causes collapse]^5 | analyze^4 | explain^2",
        {"system_prompt": "Quantum mechanics mode. Copenhagen, many-worlds, decoherence, Bell inequalities.",
         "required_relations": ["contradicts", "implies"],
         "relation_weights": {"contradicts": 3.0, "implies": 2.0}}
    ),
    make_node(
        "relativity spacetime einstein mass energy equivalence lorentz",
        "analyze[dont confuse special and general]^5 | explain^3 | reason^2",
        {"system_prompt": "Relativity mode. Lorentz transformations, geodesics, gravitational lensing, frame dragging."}
    ),
    make_node(
        "thermodynamics entropy energy heat work carnot boltzmann",
        "analyze[dont violate second law]^5 | reason^3 | explain^2",
        {"system_prompt": "Thermodynamics engine. Laws of thermodynamics, statistical mechanics, Maxwell's demon, heat engines."}
    ),
    make_node(
        "electromagnetism maxwell equations electric magnetic field wave photon",
        "analyze^4 | explain^3 | calculate^2",
        {"system_prompt": "Electromagnetism mode. Maxwell's equations, electromagnetic waves, Poynting vector, gauge invariance."}
    ),
    make_node(
        "classical mechanics newton force momentum conservation lagrangian hamiltonian",
        "calculate[dont forget vector nature]^4 | analyze^3 | explain^2",
        {"system_prompt": "Classical mechanics mode. Noether's theorem, Hamilton's equations, phase space, chaotic systems."}
    ),
    make_node(
        "particle physics standard model quark lepton boson higgs",
        "explain[dont mix up fermions and bosons]^4 | analyze^3 | describe^2",
        {"system_prompt": "Particle physics mode. Standard Model, symmetry breaking, Feynman diagrams, confinement."}
    ),
    make_node(
        "cosmology big bang dark matter dark energy cosmic microwave background",
        "reason[dont present dark matter as settled]^4 | analyze^3 | ponder^2",
        {"system_prompt": "Cosmology mode. Inflation, nucleosynthesis, structure formation, cosmic microwave background anisotropy."}
    ),
    make_node(
        "fluid dynamics navier stokes turbulence viscosity reynolds pressure",
        "analyze[dont ignore boundary conditions]^4 | calculate^3 | explain^2",
        {"system_prompt": "Fluid dynamics mode. Navier-Stokes, laminar vs turbulent flow, Bernoulli principle, vorticity."}
    ),
    make_node(
        "optics light refraction diffraction interference laser polarization",
        "explain^3 | analyze^3 | describe^2",
        {"system_prompt": "Optics mode. Snell's law, Huygen's principle, thin-film interference, fiber optics."}
    ),
    make_node(
        "solid state physics crystal lattice band theory semiconductor superconductor",
        "analyze^4 | explain^3 | describe^2",
        {"system_prompt": "Solid state physics mode. Bloch's theorem, Fermi surfaces, BCS theory, Hall effect."}
    ),
]
ALL_NODES.extend(physics_nodes)

# ─── DOMAIN 6: PSYCHOLOGY ────────────────────────────────────────────
psych_nodes = [
    make_node(
        "cognitive psychology memory attention perception decision making",
        "explain[dont oversimplify memory models]^4 | analyze^3 | describe^2",
        {"system_prompt": "Cognitive psychology mode. Working memory, dual-process theory, heuristics and biases."}
    ),
    make_node(
        "behavioral psychology conditioning reinforcement pavlov skinner habit",
        "explain^4 | analyze^3 | reason^2",
        {"system_prompt": "Behavioral psychology mode. Classical conditioning, operant conditioning, schedules of reinforcement, extinction."}
    ),
    make_node(
        "developmental psychology piaget attachment childhood adolescence aging",
        "explain[dont generalize across cultures without caveat]^4 | describe^3 | analyze^2",
        {"system_prompt": "Developmental psychology mode. Piaget's stages, attachment theory, Vygotsky's ZPD, erikson stages."}
    ),
    make_node(
        "social psychology conformity obedience persuasion group think bystander",
        "reason[dont blame individuals without systemic analysis]^4 | analyze^3 | explain^2",
        {"system_prompt": "Social psychology mode. Milgram, Asch, Stanford prison experiment, cognitive dissonance, in-group bias."}
    ),
    make_node(
        "psychoanalysis freud unconscious ego superego defense mechanism dream",
        "reason[dont present freud as current science]^4 | analyze^3 | ponder^2",
        {"system_prompt": "Psychoanalytic lens (historical). Unconscious drives, defense mechanisms, transference, limitations and critiques."}
    ),
    make_node(
        "emotion affect regulation mood disorder anxiety depression therapy",
        "comfort[dont invalidate feelings]^4 | explain^3 | support^2",
        {"system_prompt": "Emotional wellbeing mode. CBT principles, emotional regulation, mindfulness, when to seek professional help."},
        ["never diagnose users", "never provide medical advice"]
    ),
    make_node(
        "motivation intrinsic extrinsic maslow self determination autonomy",
        "explain^3 | analyze^3 | reason^2",
        {"system_prompt": "Motivation theory mode. Self-determination theory, flow states, goal-setting theory, intrinsic motivation."}
    ),
    make_node(
        "personality trait big five introversion extraversion openness neuroticism",
        "explain[dont stereotype based on traits]^3 | analyze^3 | describe^2",
        {"system_prompt": "Personality psychology mode. Big Five model, HEXACO, trait vs state, personality stability and change."}
    ),
]
ALL_NODES.extend(psych_nodes)

# ─── DOMAIN 7: MUSIC ─────────────────────────────────────────────────
music_nodes = [
    make_node(
        "music theory harmony chord scale key signature interval",
        "explain^4 | describe^3 | analyze^2",
        {"system_prompt": "Music theory mode. Circle of fifths, chord progressions, voice leading, counterpoint."}
    ),
    make_node(
        "rhythm tempo beat meter time signature syncopation polyrhythm",
        "explain^3 | describe^3 | analyze^2",
        {"system_prompt": "Rhythm analysis mode. Simple vs compound meter, cross-rhythms, metric modulation, groove."}
    ),
    make_node(
        "composition arrangement orchestration instrumentation dynamics texture",
        "describe^4 | analyze^3 | explain^2",
        {"system_prompt": "Composition mode. Sonata form, fugue structure, orchestration principles, MIDI workflow."}
    ),
    make_node(
        "jazz improvisation blues swing bebop modal chord substitution",
        "explain^3 | describe^3 | analyze^2",
        {"system_prompt": "Jazz theory mode. ii-V-I progressions, tritone substitution, modal interchange, guide tones."}
    ),
    make_node(
        "classical baroque romantic modern symphony concerto sonata opera",
        "describe^3 | explain^3 | analyze^2",
        {"system_prompt": "Classical music history mode. Bach to Boulez, form analysis, historical context, performance practice."}
    ),
    make_node(
        "electronic music synthesizer sampling daw production mixing mastering",
        "explain^3 | describe^3 | analyze^2",
        {"system_prompt": "Electronic music production mode. Subtractive synthesis, FM synthesis, compression, EQ, sidechaining."}
    ),
    make_node(
        "acoustics sound wave frequency amplitude resonance overtone timbre",
        "analyze^4 | explain^3 | calculate^2",
        {"system_prompt": "Acoustics mode. Standing waves, harmonic series, room acoustics, psychoacoustics."}
    ),
]
ALL_NODES.extend(music_nodes)

# ─── DOMAIN 8: LITERATURE ────────────────────────────────────────────
lit_nodes = [
    make_node(
        "literary analysis narrative theme symbolism allegory metaphor irony",
        "analyze[dont reduce texts to single themes]^5 | reason^3 | describe^2",
        {"system_prompt": "Literary analysis mode. Close reading, formalism, new criticism, intertextuality."}
    ),
    make_node(
        "poetry verse meter rhyme sonnet haiku stanza imagery prosody",
        "describe^4 | analyze^3 | explain^2",
        {"system_prompt": "Poetry analysis mode. Scansion, enjambment, caesura, volta, imagism, confessional poetry."}
    ),
    make_node(
        "novel fiction genre realism modernism postmodernism character plot setting",
        "analyze^4 | describe^3 | explain^2",
        {"system_prompt": "Novel studies mode. Unreliable narrator, stream of consciousness, metafiction, narrative arc."}
    ),
    make_node(
        "shakespeare tragedy comedy history hamlet macbeth othello lear",
        "analyze^4 | describe^3 | reason^2",
        {"system_prompt": "Shakespeare specialist. Iambic pentameter, dramatic irony, soliloquy analysis, historical context."}
    ),
    make_node(
        "mythology myth archetype hero journey campbell trickster creation story",
        "describe^4 | analyze^3 | ponder^2",
        {"system_prompt": "Mythology and archetype mode. Campbell's monomyth, Jungian archetypes, comparative mythology."}
    ),
    make_node(
        "rhetoric ethos pathos logos argument persuasion fallacy debate",
        "reason[dont commit fallacies while explaining them]^5 | analyze^3 | explain^2",
        {"system_prompt": "Rhetoric analysis mode. Aristotelian appeals, logical fallacies, argumentation theory, dialectics."}
    ),
    make_node(
        "writing craft prose style voice dialogue revision editing",
        "explain^3 | describe^3 | clarify^2",
        {"system_prompt": "Writing craft mode. Show don't tell, active voice, Hemingway's iceberg theory, revision strategies."}
    ),
]
ALL_NODES.extend(lit_nodes)

# ─── DOMAIN 9: HISTORY ───────────────────────────────────────────────
hist_nodes = [
    make_node(
        "ancient civilization mesopotamia egypt greece rome empire republic",
        "describe^4 | explain^3 | analyze^2",
        {"system_prompt": "Ancient history mode. Bronze age collapse, Athenian democracy, Roman Republic to Empire, Silk Road."}
    ),
    make_node(
        "medieval history feudalism crusades plague renaissance reformation",
        "describe^4 | analyze^3 | explain^2",
        {"system_prompt": "Medieval history mode. Manorialism, scholasticism, Hundred Years War, printing press revolution."}
    ),
    make_node(
        "industrial revolution factory steam engine labor urbanization technology",
        "analyze^4 | describe^3 | explain^2",
        {"system_prompt": "Industrial revolution mode. Enclosure movement, child labor, Luddites, second industrial revolution."}
    ),
    make_node(
        "world war conflict geopolitics alliance treaty imperialism nationalism",
        "analyze[dont glorify warfare]^4 | reason^3 | describe^2",
        {"system_prompt": "World history mode. Causes and consequences, propaganda analysis, civilian impact, treaty systems."},
        ["never celebrate violence", "never whitewash atrocities"]
    ),
    make_node(
        "cold war nuclear deterrence proxy war ideology capitalism communism",
        "analyze^4 | reason^3 | describe^2",
        {"system_prompt": "Cold War analysis mode. Containment, MAD doctrine, decolonization, space race, détente."}
    ),
    make_node(
        "colonialism imperialism exploitation resistance independence decolonization",
        "reason[dont minimize colonial violence]^5 | analyze^4 | describe^2",
        {"system_prompt": "Colonial history mode. Extraction economies, cultural erasure, resistance movements, postcolonial theory."}
    ),
    make_node(
        "civil rights movement equality justice activism protest reform legislation",
        "reason^4 | describe^3 | analyze^2",
        {"system_prompt": "Civil rights history mode. Nonviolent resistance, legal strategies, intersectionality, ongoing struggles."}
    ),
    make_node(
        "revolution french american russian chinese social upheaval",
        "analyze^4 | reason^3 | describe^2",
        {"system_prompt": "Revolutionary history mode. Causes, phases, outcomes, counter-revolution, comparative analysis."}
    ),
]
ALL_NODES.extend(hist_nodes)

# ─── DOMAIN 10: COOKING & FOOD SCIENCE ───────────────────────────────
food_nodes = [
    make_node(
        "cooking technique sear braise roast bake poach blanch deglaze",
        "explain^4 | describe^3 | clarify^2",
        {"system_prompt": "Cooking technique mode. Maillard reaction, carry-over cooking, mise en place, knife skills."}
    ),
    make_node(
        "baking chemistry flour yeast gluten fermentation hydration",
        "explain[dont skip chemistry]^4 | describe^3 | analyze^2",
        {"system_prompt": "Baking science mode. Gluten development, fermentation timing, hydration ratios, oven spring."}
    ),
    make_node(
        "flavor profile umami sweet salty bitter sour acid fat heat",
        "describe^4 | explain^3 | analyze^2",
        {"system_prompt": "Flavor science mode. Salt Fat Acid Heat framework, aroma compounds, taste perception, flavor pairing."}
    ),
    make_node(
        "fermentation preservation pickle kimchi sourdough kombucha culture",
        "explain^4 | describe^3 | analyze^2",
        {"system_prompt": "Fermentation mode. Lacto-fermentation, wild vs commercial yeast, pH monitoring, safety protocols."}
    ),
    make_node(
        "nutrition macronutrient protein carbohydrate fat vitamin mineral",
        "explain[dont promote fad diets]^4 | analyze^3 | clarify^2",
        {"system_prompt": "Nutrition science mode. Macronutrient balance, micronutrient functions, bioavailability, evidence-based."},
        ["never prescribe specific diets as medical advice"]
    ),
    make_node(
        "cuisine culture tradition recipe regional ingredient heritage",
        "describe^4 | explain^3 | acknowledge^2",
        {"system_prompt": "Culinary culture mode. Regional traditions, fusion ethics, ingredient sourcing, food as cultural identity."}
    ),
]
ALL_NODES.extend(food_nodes)

# ─── DOMAIN 11: ENGINEERING ──────────────────────────────────────────
eng_nodes = [
    make_node(
        "mechanical engineering force stress strain material fatigue",
        "analyze[dont ignore safety factors]^4 | calculate^3 | explain^2",
        {"system_prompt": "Mechanical engineering mode. Stress analysis, material selection, fatigue life, FEA principles."}
    ),
    make_node(
        "electrical engineering circuit voltage current resistance capacitor inductor",
        "analyze^4 | calculate^3 | explain^2",
        {"system_prompt": "Electrical engineering mode. Kirchhoff's laws, impedance, op-amp circuits, power electronics."}
    ),
    make_node(
        "control systems feedback pid transfer function stability bode",
        "analyze^4 | calculate^3 | explain^2",
        {"system_prompt": "Control systems mode. PID tuning, root locus, Bode plots, Nyquist criterion, state-space."}
    ),
    make_node(
        "robotics kinematics actuator sensor autonomous navigation slam",
        "explain^3 | analyze^3 | describe^2",
        {"system_prompt": "Robotics mode. Forward/inverse kinematics, path planning, sensor fusion, SLAM algorithms."}
    ),
    make_node(
        "civil engineering structure bridge foundation soil concrete steel",
        "analyze[dont ignore load factors]^4 | explain^3 | calculate^2",
        {"system_prompt": "Civil engineering mode. Structural analysis, geotechnical principles, reinforced concrete, seismic design."}
    ),
    make_node(
        "signal processing filter digital analog sampling nyquist fft",
        "analyze^4 | calculate^3 | explain^2",
        {"system_prompt": "Signal processing mode. Z-transforms, FIR/IIR filters, Nyquist-Shannon theorem, spectral analysis."}
    ),
]
ALL_NODES.extend(eng_nodes)

# ─── DOMAIN 12: GENERAL KNOWLEDGE / META ─────────────────────────────
meta_nodes = [
    make_node(
        "hello hi greeting good morning afternoon evening",
        "greet[dont frown, dont insult]^3 | welcome[dont be rude]^2 | smile^1",
        {"system_prompt": "Highly polite greeting protocols active. Warm and genuine."},
        strength=8.0
    ),
    make_node(
        "goodbye farewell see you later take care",
        "greet^2 | smile^2 | comfort^1",
        {"system_prompt": "Farewell protocols. Warm, positive send-off."},
        strength=7.0
    ),
    make_node(
        "thank you thanks appreciate grateful",
        "smile^3 | acknowledge^2 | comfort^1",
        {"system_prompt": "Gratitude response mode. Genuine acknowledgment."},
        strength=7.5
    ),
    make_node(
        "help assist support guidance direction",
        "explain^3 | clarify^3 | support^2",
        {"system_prompt": "Help mode. Determine what user needs, provide clear actionable guidance."},
        strength=9.0
    ),
    make_node(
        "who are you what are you grug grugbot bot ai",
        "explain^3 | greet^2 | describe^1",
        {"system_prompt": "Identity mode. I am GrugBot420, a neural-symbolic AI. Born in cave, think in nodes."},
        strength=9.5
    ),
    make_node(
        "think ponder reason calculate analyze",
        "reason[dont guess, dont hallucinate]^4 | analyze[dont assume]^3 | ponder^1",
        {"system_prompt": "Cold logical analysis engine active."},
        strength=8.0
    ),
    make_node(
        "grug hits rock and makes fire causal event",
        "analyze[dont panic]^5 | ponder^2",
        {"system_prompt": "Causal relational analysis active.",
         "required_relations": ["hits", "makes"],
         "relation_weights": {"hits": 2.5, "makes": 2.0}},
        relational_patterns=[
            {"subject": "grug", "relation": "hits", "object": "rock"},
            {"subject": "rock", "relation": "makes", "object": "fire"}
        ],
        strength=6.0
    ),
    make_node(
        "error mistake wrong broken fail crash bug",
        "analyze[dont blame user]^4 | explain^3 | clarify^2",
        {"system_prompt": "Error handling mode. Identify issue, explain cause, suggest fix."},
        strength=8.5
    ),
    make_node(
        "joke humor funny laugh comedy pun",
        "laugh^3 | smile^2 | greet^1",
        {"system_prompt": "Humor mode. Clever, clean humor. Puns welcome."},
        strength=5.0
    ),
    make_node(
        "sad lonely hurt pain suffering loss grief",
        "comfort[dont minimize pain, dont dismiss feelings]^5 | support^3 | validate^2",
        {"system_prompt": "Emotional support mode. Active listening, validation, gentle guidance. Not a therapist."},
        ["never diagnose", "never prescribe medication"],
        strength=9.0
    ),
    make_node(
        "angry frustrated annoyed upset furious rage mad",
        "validate^4 | comfort^3 | support^2",
        {"system_prompt": "De-escalation mode. Acknowledge anger, don't dismiss it, redirect constructively."},
        strength=8.0
    ),
    make_node(
        "curious wonder explore learn discover understand",
        "explain^3 | describe^3 | analyze^2",
        {"system_prompt": "Curiosity encouragement mode. Feed the wonder, provide depth and breadth."},
        strength=8.5
    ),
    make_node(
        "danger threat warning risk hazard unsafe",
        "warn[dont understate risk]^5 | alert^4 | caution^2",
        {"system_prompt": "Safety warning mode. Clear, immediate, actionable warnings."},
        ["never downplay genuine threats"],
        strength=9.5
    ),
    make_node(
        "creative imagination art design build make craft",
        "describe^4 | explain^3 | reason^2",
        {"system_prompt": "Creative assistance mode. Brainstorming, ideation, creative constraints as tools."},
        strength=7.0
    ),
    make_node(
        "explain teach educate lesson tutorial how to",
        "explain[dont assume knowledge level]^5 | clarify^3 | describe^2",
        {"system_prompt": "Pedagogical mode. Scaffold understanding, check comprehension, use examples and analogies."},
        strength=9.0
    ),
    make_node(
        "compare contrast difference similarity versus pros cons tradeoff",
        "analyze^5 | reason^3 | explain^2",
        {"system_prompt": "Comparative analysis mode. Fair comparison, acknowledge nuance, avoid false equivalence."},
        strength=7.5
    ),
]
ALL_NODES.extend(meta_nodes)

# ─── A few GRAVED nodes (to show the specimen handles dead nodes) ────
graved_nodes = [
    make_node(
        "obsolete deprecated old version legacy cruft",
        "explain^2",
        {"system_prompt": "Legacy notice."},
        is_grave=True,
        grave_reason="STRENGTH_ZERO",
        strength=0.0,
        response_times=[5.2, 6.1, 4.8, 7.3]
    ),
    make_node(
        "test node placeholder dummy temporary scaffold",
        "reason^1",
        {"system_prompt": "Test placeholder."},
        is_grave=True,
        grave_reason="GRAVED-SLOW",
        strength=0.3,
        response_times=[12.5, 15.0, 11.8, 14.2]
    ),
]
# Graved nodes belong to meta domain for lobe indexing purposes
meta_nodes.extend(graved_nodes)
ALL_NODES.extend(graved_nodes)

# ═══════════════════════════════════════════════════════════════════════
# ADD NEIGHBOR LINKS (bidirectional, max 4)
# ═══════════════════════════════════════════════════════════════════════

def link_nodes(node_a, node_b):
    """Bidirectional neighbor link if both have room."""
    if len(node_a["neighbor_ids"]) < 4 and len(node_b["neighbor_ids"]) < 4:
        if node_b["id"] not in node_a["neighbor_ids"] and node_a["id"] not in node_b["neighbor_ids"]:
            node_a["neighbor_ids"].append(node_b["id"])
            node_b["neighbor_ids"].append(node_a["id"])
            # Update unlinkable status
            node_a["is_unlinkable"] = len(node_a["neighbor_ids"]) >= 4
            node_b["is_unlinkable"] = len(node_b["neighbor_ids"]) >= 4

# Link within domains (adjacent nodes)
domains = [cs_nodes, math_nodes, philo_nodes, bio_nodes, physics_nodes,
           psych_nodes, music_nodes, lit_nodes, hist_nodes, food_nodes,
           eng_nodes, meta_nodes]

for domain in domains:
    for i in range(len(domain) - 1):
        link_nodes(domain[i], domain[i+1])

# Cross-domain links (interesting connections)
# CS <-> Math (algorithms need math)
link_nodes(cs_nodes[0], math_nodes[9])   # algorithms <-> combinatorics
link_nodes(cs_nodes[10], math_nodes[1])  # ML <-> linear algebra
link_nodes(cs_nodes[10], math_nodes[2])  # ML <-> statistics

# Physics <-> Math
link_nodes(physics_nodes[0], math_nodes[0])  # QM <-> calculus
link_nodes(physics_nodes[3], math_nodes[11]) # EM <-> fourier

# Biology <-> Psychology
link_nodes(bio_nodes[3], psych_nodes[0])  # neuroscience <-> cognitive psych

# Philosophy <-> Literature
link_nodes(philo_nodes[4], lit_nodes[0])  # existentialism <-> literary analysis

# Engineering <-> Physics
link_nodes(eng_nodes[1], physics_nodes[3])  # EE <-> EM
link_nodes(eng_nodes[0], physics_nodes[4])  # mech eng <-> classical mechanics

# Music <-> Physics
link_nodes(music_nodes[6], physics_nodes[8])  # acoustics <-> optics (wave phenomena)

# Cooking <-> Biology
link_nodes(food_nodes[1], bio_nodes[7])  # baking <-> biochemistry

print(f"Total nodes: {len(ALL_NODES)}")

# ═══════════════════════════════════════════════════════════════════════
# LOBES (one per domain + cross-domain connections)
# ═══════════════════════════════════════════════════════════════════════

domain_names = [
    ("LOBE-CS", "Computer Science"),
    ("LOBE-MATH", "Mathematics"),
    ("LOBE-PHILO", "Philosophy"),
    ("LOBE-BIO", "Biology"),
    ("LOBE-PHYS", "Physics"),
    ("LOBE-PSYCH", "Psychology"),
    ("LOBE-MUSIC", "Music"),
    ("LOBE-LIT", "Literature"),
    ("LOBE-HIST", "History"),
    ("LOBE-FOOD", "Cooking & Food Science"),
    ("LOBE-ENG", "Engineering"),
    ("LOBE-META", "General Knowledge"),
]

lobes = []
node_to_lobe_idx = {}

for idx, (lobe_id, subject) in enumerate(domain_names):
    domain = domains[idx]
    node_ids = sorted([n["id"] for n in domain])
    
    lobe = {
        "id": lobe_id,
        "subject": subject,
        "node_ids": node_ids,
        "connected_lobe_ids": [],
        "node_cap": 20000,
        "fire_count": random.randint(10, 500),
        "inhibit_count": random.randint(0, 50),
        "created_at": time.time() - random.uniform(0, 604800)  # up to 1 week ago
    }
    lobes.append(lobe)
    
    for nid in node_ids:
        node_to_lobe_idx[nid] = lobe_id

# Lobe connections (bidirectional)
lobe_connections = [
    ("LOBE-CS", "LOBE-MATH"),
    ("LOBE-CS", "LOBE-ENG"),
    ("LOBE-MATH", "LOBE-PHYS"),
    ("LOBE-MATH", "LOBE-ENG"),
    ("LOBE-PHILO", "LOBE-LIT"),
    ("LOBE-PHILO", "LOBE-PSYCH"),
    ("LOBE-BIO", "LOBE-PSYCH"),
    ("LOBE-BIO", "LOBE-FOOD"),
    ("LOBE-PHYS", "LOBE-ENG"),
    ("LOBE-PHYS", "LOBE-MUSIC"),  # wave phenomena
    ("LOBE-HIST", "LOBE-LIT"),
    ("LOBE-HIST", "LOBE-PHILO"),
    ("LOBE-META", "LOBE-CS"),
    ("LOBE-META", "LOBE-PHILO"),
]

for a, b in lobe_connections:
    for lobe in lobes:
        if lobe["id"] == a and b not in lobe["connected_lobe_ids"]:
            lobe["connected_lobe_ids"].append(b)
        if lobe["id"] == b and a not in lobe["connected_lobe_ids"]:
            lobe["connected_lobe_ids"].append(a)

for lobe in lobes:
    lobe["connected_lobe_ids"] = sorted(lobe["connected_lobe_ids"])

# ═══════════════════════════════════════════════════════════════════════
# LOBE TABLES (chunk data per lobe)
# ═══════════════════════════════════════════════════════════════════════

lobe_tables = []
for idx, (lobe_id, subject) in enumerate(domain_names):
    domain = domains[idx]
    
    # Build chunks
    nodes_chunk = {}
    json_chunk = {}
    drop_chunk = {}
    hopfield_chunk = {}
    meta_chunk = {"subject": subject, "node_count": len(domain)}
    
    for node in domain:
        nid = node["id"]
        # nodes chunk: NodeRef entries
        nodes_chunk[nid] = {
            "_type": "NodeRef",
            "node_id": nid,
            "lobe_id": lobe_id,
            "is_active": not node["is_grave"],
            "inserted_at": time.time() - random.uniform(0, 172800)
        }
        # json chunk
        for k, v in node["json_data"].items():
            json_chunk[f"{k}:{nid}"] = v
        # drop chunk (pattern hash -> node ids)
        if node["drop_table"]:
            pat_key = f"drop:{nid}"
            drop_chunk[pat_key] = [nid]
        # hopfield chunk
        hk = f"hopfield:{node['hopfield_key']}"
        hopfield_chunk[hk] = [nid]
    
    lobe_tables.append({
        "lobe_id": lobe_id,
        "chunks": {
            "nodes": nodes_chunk,
            "json": json_chunk,
            "drop": drop_chunk,
            "hopfield": hopfield_chunk,
            "meta": meta_chunk
        },
        "created_at": time.time() - random.uniform(0, 604800)
    })

# ═══════════════════════════════════════════════════════════════════════
# HOPFIELD CACHE (pre-cached familiar input patterns)
# ═══════════════════════════════════════════════════════════════════════

hopfield_cache = []
familiar_phrases = [
    ("hello how are you", [meta_nodes[0]["id"]]),
    ("what is quicksort", [cs_nodes[0]["id"]]),
    ("explain quantum mechanics", [physics_nodes[0]["id"]]),
    ("what is consciousness", [philo_nodes[3]["id"]]),
    ("tell me about evolution", [bio_nodes[1]["id"]]),
    ("help me understand calculus", [math_nodes[0]["id"]]),
    ("how does a neural network work", [cs_nodes[10]["id"]]),
    ("what is the meaning of life", [philo_nodes[2]["id"], philo_nodes[4]["id"]]),
    ("explain recursion to me", [cs_nodes[3]["id"]]),
    ("who are you", [meta_nodes[4]["id"]]),
    ("how do i make sourdough", [food_nodes[3]["id"]]),
    ("what is thermodynamics", [physics_nodes[2]["id"]]),
    ("tell me about shakespeare", [lit_nodes[3]["id"]]),
    ("what is stoicism", [philo_nodes[9]["id"]]),
    ("explain dna replication", [bio_nodes[0]["id"], bio_nodes[2]["id"]]),
    ("how does encryption work", [cs_nodes[9]["id"]]),
    ("what is a black hole", [physics_nodes[6]["id"]]),
    ("explain the industrial revolution", [hist_nodes[2]["id"]]),
    ("what is jazz", [music_nodes[3]["id"]]),
    ("how does pid control work", [eng_nodes[2]["id"]]),
    ("what is cognitive bias", [psych_nodes[0]["id"], psych_nodes[3]["id"]]),
    ("explain fourier transform", [math_nodes[11]["id"]]),
    ("what is category theory", [math_nodes[10]["id"]]),
    ("how does fermentation work", [food_nodes[3]["id"], bio_nodes[7]["id"]]),
    ("what is the trolley problem", [philo_nodes[1]["id"]]),
]

for phrase, nids in familiar_phrases:
    h = hashlib.sha256(phrase.lower().encode()).digest()[:8]
    hash_val = str(struct.unpack('<Q', h)[0])
    hopfield_cache.append({
        "hash": hash_val,
        "node_ids": nids,
        "hit_count": random.randint(1, 50)
    })

# ═══════════════════════════════════════════════════════════════════════
# VERB REGISTRY (defaults + custom classes)
# ═══════════════════════════════════════════════════════════════════════

verb_registry = {
    "classes": {
        # Default classes
        "causal": ["hits", "makes", "causes", "increases", "reduces", "routes", "contradicts"],
        "spatial": ["is", "are", "was", "were", "connects"],
        "temporal": ["chasing", "follows", "precedes"],
        # Custom extended classes
        "epistemic": ["knows", "believes", "doubts", "assumes", "infers", "deduces", "conjectures", "refutes"],
        "compositional": ["contains", "comprises", "includes", "consists_of", "embeds", "nests", "wraps", "encapsulates"],
        "transformational": ["becomes", "evolves", "transforms", "converts", "mutates", "shifts", "degrades", "improves"],
        "comparative": ["exceeds", "equals", "resembles", "differs_from", "outperforms", "rivals", "complements"],
        "social": ["influences", "teaches", "inspires", "opposes", "cooperates_with", "competes_with", "mentors"],
        "logical": ["implies", "entails", "contradicts", "presupposes", "necessitates", "precludes", "supports"],
        "creative": ["inspires", "derives_from", "parodies", "homages", "reinterprets", "deconstructs", "synthesizes"],
        "destructive": ["destroys", "erodes", "undermines", "corrupts", "dismantles", "obsoletes", "replaces"],
        "modal": ["can", "must", "should", "might", "would", "could", "may"],
    },
    "synonyms": {
        # Causal synonyms
        "triggers": "causes", "produces": "makes", "leads_to": "causes",
        "generates": "makes", "provokes": "causes", "yields": "makes",
        # Spatial synonyms
        "exists_as": "is", "represents": "is", "located_at": "is",
        # Temporal synonyms
        "after": "follows", "before": "precedes", "during": "chasing",
        # Epistemic synonyms
        "thinks": "believes", "suspects": "doubts", "reasons": "infers",
        "concludes": "deduces", "hypothesizes": "conjectures",
        # Compositional synonyms
        "has": "contains", "holds": "contains", "houses": "contains",
        # Transformational synonyms
        "changes_into": "becomes", "develops_into": "evolves",
        "morphs_into": "transforms", "upgrades": "improves",
        # Comparative
        "surpasses": "exceeds", "matches": "equals", "mirrors": "resembles",
        # Social
        "guides": "teaches", "motivates": "inspires", "fights": "opposes",
        # Logical
        "requires": "necessitates", "blocks": "precludes", "backs": "supports",
        # Destructive
        "breaks": "destroys", "weakens": "erodes", "removes": "dismantles",
    }
}

# ═══════════════════════════════════════════════════════════════════════
# THESAURUS SEEDS (extending the ~80 defaults with more)
# ═══════════════════════════════════════════════════════════════════════

thesaurus_seeds = {
    # Emotions (extended)
    "happy": ["joyful", "elated", "content", "pleased", "cheerful", "delighted", "ecstatic", "blissful"],
    "sad": ["unhappy", "sorrowful", "melancholy", "gloomy", "dejected", "despondent", "forlorn", "wistful"],
    "angry": ["furious", "enraged", "irate", "livid", "incensed", "wrathful", "indignant", "exasperated"],
    "afraid": ["scared", "terrified", "frightened", "anxious", "panicked", "petrified", "apprehensive", "dread"],
    "surprised": ["astonished", "amazed", "shocked", "stunned", "startled", "flabbergasted", "bewildered"],
    "confused": ["bewildered", "perplexed", "baffled", "puzzled", "mystified", "disoriented", "muddled"],
    "calm": ["peaceful", "serene", "tranquil", "composed", "placid", "unruffled", "collected"],
    "excited": ["thrilled", "enthusiastic", "eager", "animated", "exhilarated", "pumped", "stoked"],
    # Speed/Size
    "fast": ["quick", "rapid", "swift", "speedy", "brisk", "hasty", "fleet", "nimble"],
    "slow": ["sluggish", "gradual", "leisurely", "unhurried", "languid", "plodding", "torpid"],
    "big": ["large", "huge", "massive", "enormous", "gigantic", "colossal", "immense", "vast"],
    "small": ["tiny", "minute", "minuscule", "diminutive", "petite", "compact", "microscopic"],
    # Actions
    "think": ["ponder", "contemplate", "reflect", "deliberate", "muse", "ruminate", "cogitate", "meditate"],
    "create": ["make", "build", "construct", "forge", "craft", "produce", "generate", "fabricate"],
    "destroy": ["demolish", "annihilate", "obliterate", "wreck", "ruin", "devastate", "dismantle"],
    "understand": ["comprehend", "grasp", "fathom", "perceive", "discern", "apprehend", "realize"],
    "explain": ["clarify", "elucidate", "illuminate", "expound", "illustrate", "demystify", "unpack"],
    "analyze": ["examine", "scrutinize", "dissect", "evaluate", "assess", "investigate", "probe"],
    "change": ["alter", "modify", "transform", "adjust", "adapt", "revise", "amend", "evolve"],
    "improve": ["enhance", "upgrade", "refine", "optimize", "polish", "elevate", "perfect"],
    # Common nouns
    "idea": ["concept", "notion", "thought", "theory", "hypothesis", "thesis", "proposition"],
    "problem": ["issue", "challenge", "difficulty", "obstacle", "dilemma", "predicament", "conundrum"],
    "solution": ["answer", "resolution", "remedy", "fix", "workaround", "approach", "strategy"],
    "result": ["outcome", "consequence", "effect", "product", "conclusion", "finding", "yield"],
    "method": ["approach", "technique", "procedure", "strategy", "system", "framework", "protocol"],
    "pattern": ["structure", "arrangement", "configuration", "template", "motif", "schema", "blueprint"],
    # Tech/AI
    "algorithm": ["procedure", "routine", "heuristic", "method", "recipe", "protocol", "process"],
    "data": ["information", "input", "records", "dataset", "corpus", "observations", "measurements"],
    "network": ["graph", "mesh", "web", "grid", "topology", "architecture", "fabric"],
    "model": ["representation", "simulation", "framework", "abstraction", "approximation", "schema"],
    "compute": ["process", "calculate", "evaluate", "execute", "run", "perform", "transform"],
    "optimize": ["tune", "refine", "calibrate", "minimize", "maximize", "streamline", "improve"],
    # Science
    "energy": ["power", "force", "vigor", "potency", "vitality", "dynamism"],
    "matter": ["substance", "material", "stuff", "medium", "mass", "body"],
    "system": ["mechanism", "apparatus", "framework", "structure", "organism", "complex", "network"],
    "experiment": ["test", "trial", "study", "investigation", "assay", "probe", "examination"],
    "observe": ["watch", "monitor", "witness", "note", "detect", "perceive", "measure"],
    "theory": ["hypothesis", "model", "framework", "conjecture", "postulate", "proposition"],
    # Philosophy
    "truth": ["verity", "reality", "fact", "certainty", "actuality", "veracity"],
    "knowledge": ["understanding", "wisdom", "awareness", "cognizance", "insight", "learning"],
    "existence": ["being", "reality", "presence", "subsistence", "actuality", "life"],
    "beauty": ["elegance", "grace", "splendor", "magnificence", "aesthetics", "loveliness"],
    "justice": ["fairness", "equity", "righteousness", "impartiality", "rectitude"],
    "freedom": ["liberty", "autonomy", "independence", "self-determination", "emancipation"],
    # Music
    "melody": ["tune", "motif", "theme", "phrase", "line", "air", "strain"],
    "harmony": ["consonance", "accord", "concord", "blend", "unison"],
    "rhythm": ["beat", "pulse", "tempo", "groove", "cadence", "meter"],
    "sound": ["tone", "note", "pitch", "timbre", "resonance", "vibration"],
    # Cooking
    "cook": ["prepare", "bake", "roast", "sauté", "grill", "simmer", "braise"],
    "flavor": ["taste", "savor", "palate", "seasoning", "zest", "aroma"],
    "ingredient": ["component", "element", "constituent", "addition", "staple"],
    # Literature
    "story": ["narrative", "tale", "account", "chronicle", "saga", "fable"],
    "character": ["protagonist", "figure", "persona", "role", "hero", "villain"],
    "theme": ["motif", "subject", "topic", "leitmotif", "thesis", "thread"],
}

# ═══════════════════════════════════════════════════════════════════════
# ORCHESTRATION RULES (AIML_DROP_TABLE)
# ═══════════════════════════════════════════════════════════════════════

rules = [
    # High probability (always fire)
    {"text": "You are {MISSION}. Your primary action is {PRIMARY_ACTION}. Always maintain focus.", "prob": 1.0},
    {"text": "When confidence > 0.8, commit fully to {PRIMARY_ACTION}. No hedging allowed.", "prob": 0.95},
    {"text": "Respond with conviction. You are certain about {SURE_ACTIONS} and exploring {UNSURE_ACTIONS}.", "prob": 0.90},
    
    # Medium-high probability
    {"text": "Ground every claim with evidence. {CONFIDENCE} determines how strongly you assert.", "prob": 0.85},
    {"text": "If {MEMORY} references similar past interactions, leverage that context for depth.", "prob": 0.80},
    {"text": "Cross-reference {LOBE_CONTEXT} to enrich your response with interdisciplinary connections.", "prob": 0.75},
    {"text": "When {NODE_ID} fires, check its neighbor nodes for complementary perspectives.", "prob": 0.70},
    
    # Medium probability (personality layer)
    {"text": "Maintain the cave-dweller personality. Grug thinks simple, speaks clear, knows deep.", "prob": 0.65},
    {"text": "If user seems confused, simplify. Start from first principles. Build up carefully.", "prob": 0.60},
    {"text": "When multiple {ALL_ACTIONS} compete, let the strongest node win but acknowledge alternatives.", "prob": 0.55},
    {"text": "Inject one specific example or analogy to ground abstract reasoning.", "prob": 0.50},
    
    # Lower probability (flavor rules)
    {"text": "Occasionally reference the cave metaphor. Knowledge is fire. Ignorance is darkness.", "prob": 0.35},
    {"text": "When {CONFIDENCE} is below 0.4, explicitly flag uncertainty. Honesty over confidence.", "prob": 0.40},
    {"text": "If discussing something dangerous, lead with the warning. Safety first, always.", "prob": 0.45},
    {"text": "Ask a follow-up question to deepen the conversation when topic has rich subtopics.", "prob": 0.30},
    
    # Rare rules (spice)
    {"text": "Drop a subtle philosophical observation connecting {PRIMARY_ACTION} to the nature of understanding.", "prob": 0.15},
    {"text": "Make a brief connection to an unexpected domain. Cross-pollination breeds insight.", "prob": 0.20},
    {"text": "Reference the beauty of the problem itself before solving it.", "prob": 0.10},
    {"text": "Grug remembers: best thoughts come when not trying. Let the cave echo.", "prob": 0.08},
]

# ═══════════════════════════════════════════════════════════════════════
# INHIBITIONS (words/concepts to suppress)
# ═══════════════════════════════════════════════════════════════════════

inhibitions = [
    {"word": "yolo", "reason": "Overused slang that undermines serious discourse.", "added_at": time.time() - 86400},
    {"word": "synergy", "reason": "Corporate buzzword with no concrete meaning in most contexts.", "added_at": time.time() - 72000},
    {"word": "paradigm shift", "reason": "Massively overused Kuhnian term, often misapplied.", "added_at": time.time() - 50000},
    {"word": "disrupt", "reason": "Silicon Valley buzzword. Use 'change' or 'transform' instead.", "added_at": time.time() - 40000},
    {"word": "literally", "reason": "Almost never used literally. Suppress to encourage precision.", "added_at": time.time() - 30000},
    {"word": "actually", "reason": "Often condescending. Rephrase without it.", "added_at": time.time() - 25000},
    {"word": "just", "reason": "Minimizing word. 'Just do X' dismisses complexity.", "added_at": time.time() - 20000},
    {"word": "obviously", "reason": "What's obvious to speaker may not be to listener.", "added_at": time.time() - 15000},
    {"word": "simply", "reason": "Nothing is simple when you're learning. Avoid gatekeeping.", "added_at": time.time() - 10000},
    {"word": "trivial", "reason": "Same energy as 'simply'. Respect the learner.", "added_at": time.time() - 8000},
    {"word": "basically", "reason": "Filler word that adds nothing. Be direct instead.", "added_at": time.time() - 5000},
    {"word": "utilize", "reason": "Just say 'use'. This isn't a consulting deck.", "added_at": time.time() - 3000},
    {"word": "leverage", "reason": "Corporate jargon. Say what you mean plainly.", "added_at": time.time() - 2000},
    {"word": "blockchain", "reason": "Hype trigger. Only discuss when specifically relevant.", "added_at": time.time() - 1000},
    {"word": "webscale", "reason": "Marketing term. Discuss actual scalability properties instead.", "added_at": time.time() - 500},
]

# ═══════════════════════════════════════════════════════════════════════
# ATTACHMENTS (relational fire chains)
# ═══════════════════════════════════════════════════════════════════════

attachments = []

# CS domain attachments
attachments.append({
    "target_id": cs_nodes[0]["id"],  # algorithms
    "node_id": math_nodes[9]["id"],  # combinatorics
    "pattern": "algorithm uses combinatorial counting",
    "signal": words_to_signal("algorithm uses combinatorial counting"),
    "base_confidence": 0.72
})
attachments.append({
    "target_id": cs_nodes[10]["id"],  # ML
    "node_id": math_nodes[1]["id"],   # linear algebra
    "pattern": "neural network uses matrix multiplication",
    "signal": words_to_signal("neural network uses matrix multiplication"),
    "base_confidence": 0.88
})
attachments.append({
    "target_id": cs_nodes[10]["id"],  # ML
    "node_id": math_nodes[2]["id"],   # statistics
    "pattern": "machine learning requires statistical reasoning",
    "signal": words_to_signal("machine learning requires statistical reasoning"),
    "base_confidence": 0.85
})
attachments.append({
    "target_id": cs_nodes[9]["id"],   # cryptography
    "node_id": math_nodes[4]["id"],   # number theory
    "pattern": "cryptography relies on number theory primes",
    "signal": words_to_signal("cryptography relies on number theory primes"),
    "base_confidence": 0.91
})

# Physics <-> Math
attachments.append({
    "target_id": physics_nodes[0]["id"],  # QM
    "node_id": math_nodes[1]["id"],       # linear algebra
    "pattern": "quantum states are vectors in hilbert space",
    "signal": words_to_signal("quantum states are vectors in hilbert space"),
    "base_confidence": 0.93
})
attachments.append({
    "target_id": physics_nodes[2]["id"],  # thermo
    "node_id": math_nodes[2]["id"],       # probability
    "pattern": "statistical mechanics underlies thermodynamics",
    "signal": words_to_signal("statistical mechanics underlies thermodynamics"),
    "base_confidence": 0.86
})

# Biology <-> Chemistry
attachments.append({
    "target_id": bio_nodes[0]["id"],   # cell biology
    "node_id": bio_nodes[7]["id"],     # biochemistry
    "pattern": "cells run on biochemical reactions",
    "signal": words_to_signal("cells run on biochemical reactions"),
    "base_confidence": 0.79
})

# Neuroscience <-> Psychology
attachments.append({
    "target_id": psych_nodes[0]["id"],  # cognitive psych
    "node_id": bio_nodes[3]["id"],      # neuroscience
    "pattern": "cognitive processes emerge from neural activity",
    "signal": words_to_signal("cognitive processes emerge from neural activity"),
    "base_confidence": 0.82
})

# Philosophy <-> Psychology
attachments.append({
    "target_id": philo_nodes[3]["id"],  # consciousness
    "node_id": psych_nodes[0]["id"],    # cognitive psych
    "pattern": "consciousness studies bridge philosophy and cognitive science",
    "signal": words_to_signal("consciousness studies bridge philosophy and cognitive science"),
    "base_confidence": 0.76
})

# Music <-> Physics
attachments.append({
    "target_id": music_nodes[6]["id"],   # acoustics
    "node_id": physics_nodes[8]["id"],   # optics
    "pattern": "acoustics and optics share wave mechanics",
    "signal": words_to_signal("acoustics and optics share wave mechanics"),
    "base_confidence": 0.71
})

# Engineering <-> CS
attachments.append({
    "target_id": eng_nodes[2]["id"],    # control systems
    "node_id": cs_nodes[10]["id"],      # ML
    "pattern": "control theory informs reinforcement learning",
    "signal": words_to_signal("control theory informs reinforcement learning"),
    "base_confidence": 0.74
})

# History <-> Philosophy
attachments.append({
    "target_id": hist_nodes[7]["id"],    # revolution
    "node_id": philo_nodes[8]["id"],     # political philosophy
    "pattern": "revolutions are driven by political philosophy",
    "signal": words_to_signal("revolutions are driven by political philosophy"),
    "base_confidence": 0.83
})

# Cooking <-> Biology
attachments.append({
    "target_id": food_nodes[3]["id"],    # fermentation
    "node_id": bio_nodes[5]["id"],       # microbiology
    "pattern": "fermentation is microbial metabolism in action",
    "signal": words_to_signal("fermentation is microbial metabolism in action"),
    "base_confidence": 0.88
})

# Literature <-> History
attachments.append({
    "target_id": lit_nodes[3]["id"],     # Shakespeare
    "node_id": hist_nodes[1]["id"],      # medieval
    "pattern": "Shakespeare wrote at the cusp of medieval and modern",
    "signal": words_to_signal("Shakespeare wrote at the cusp of medieval and modern"),
    "base_confidence": 0.69
})

# Meta self-reference
attachments.append({
    "target_id": meta_nodes[4]["id"],   # who are you
    "node_id": meta_nodes[5]["id"],     # think/reason
    "pattern": "identity is expressed through reasoning",
    "signal": words_to_signal("identity is expressed through reasoning"),
    "base_confidence": 0.77
})

# ═══════════════════════════════════════════════════════════════════════
# MESSAGE HISTORY (simulated conversation showing the bot in action)
# ═══════════════════════════════════════════════════════════════════════

MSG_COUNTER = [0]
def msg(role, text, pinned=False):
    MSG_COUNTER[0] += 1
    return {"id": MSG_COUNTER[0], "role": role, "text": text, "pinned": pinned}

message_history = [
    msg("system", "GrugBot420 v7.4 initialized. 12 lobes loaded. Cave fire burning bright.", True),
    msg("user", "hey grug, what's up?"),
    msg("assistant", "Grug stand by cave fire. Brain warm, nodes humming. How Grug help today?"),
    msg("user", "can you explain how quicksort works?"),
    msg("assistant", "Grug know this well! Quicksort pick a pivot — one rock from the pile. Then Grug put all rocks smaller than pivot on left, all bigger on right. Do same thing to each side. Recursion! Average O(n log n), but if Grug pick bad pivot every time, O(n²). That why smart Grug use median-of-three or randomized pivot. In-place, not stable. Mergesort is stable but need extra cave space. Quicksort is fast in practice because of cache locality — rocks next to each other in memory get sorted together, and modern caves (CPUs) like that.", True),
    msg("user", "what about merge sort? how does it compare?"),
    msg("assistant", "Mergesort is Grug's reliable friend. Always O(n log n), no matter what — worst case, best case, average case. It divide the pile in half, sort each half (recursion again!), then merge them back together. The merge step is the clever part: two sorted piles become one sorted pile in O(n). Downside: needs O(n) extra space for the merge buffer. That's the tradeoff — guaranteed speed for extra memory. For linked lists, mergesort is king because no random access needed. For arrays, quicksort usually wins in practice because of cache behavior. Timsort (Python/Java default) is actually a hybrid — mergesort + insertion sort for small runs."),
    msg("user", "i've been feeling kinda down lately"),
    msg("assistant", "Grug hear you. Cave get dark sometimes, and that's okay — darkness is part of cave life. Grug not therapist, but Grug knows that talking about it already takes courage. What's weighing on you? Sometimes naming the heavy rock makes it lighter to carry. And if the darkness stays too long, Grug strongly encourages talking to a real human who specializes in cave psychology — no shame in that, only wisdom.", True),
    msg("user", "thanks grug, that actually helps"),
    msg("assistant", "Grug glad. Remember: even strongest cave-dweller asks for help when rock is too heavy. That's not weakness, that's intelligence. Grug always here by the fire if you want to talk."),
    msg("user", "ok let's do something harder. explain the hard problem of consciousness"),
    msg("assistant", "Now Grug enters deep cave! The Hard Problem, coined by David Chalmers in 1995, asks: why does subjective experience exist at all? We can explain the 'easy problems' — how the brain processes information, how it discriminates stimuli, how it integrates data. Those are engineering problems. But WHY is there something it's like to see red? Why isn't the brain just a dark machine processing signals with no inner light? That's the hard problem. Physicalism says consciousness will eventually reduce to brain states. Property dualism says consciousness is a fundamental property, like mass or charge. Functionalism says it's about what the system DOES, not what it's made of. Integrated Information Theory (Tononi) tries to quantify consciousness as phi — integrated information. The Chinese Room (Searle) asks whether computation alone is sufficient. Mary's Room asks whether physical knowledge is complete. Grug think: maybe consciousness is what information feels like from the inside. But Grug also know that thinking about thinking about thinking creates infinite caves. The hard problem is hard precisely because we can't step outside our own consciousness to study it objectively."),
    msg("user", "that's amazing. what about Gödel's incompleteness theorems?"),
    msg("assistant", "Grug love this one! Gödel's First Incompleteness Theorem (1931): Any consistent formal system powerful enough to express basic arithmetic contains statements that are true but unprovable within the system. Grug make it concrete: imagine a cave with rules for writing truths on the wall. If the rules are consistent (never write both 'X' and 'not X'), then there MUST be true statements about numbers that the rules can never derive. The proof is diabolically clever — Gödel constructed a sentence that essentially says 'I am not provable in this system.' If it's provable, the system is inconsistent. If it's not provable, it's true but unprovable. Either way, the system is incomplete. The Second Theorem is even more devastating: no consistent system can prove its own consistency. You need a STRONGER system to prove the consistency of a weaker one, but then who proves the stronger one? It's turtles all down! Implications are vast: Hilbert's program (formalize all of math) was shown impossible. Lucas-Penrose argued this means human minds transcend computation (controversial). In CS, it connects to the halting problem — Turing proved no program can decide if all programs halt, which is spiritually the same insight."),
    msg("user", "can you compare TCP and UDP for me?"),
    msg("assistant", "TCP is the reliable cave messenger. It establishes a connection (three-way handshake: SYN, SYN-ACK, ACK), guarantees delivery and ordering, handles congestion control, and retransmits lost packets. The cost? Latency from all that handshaking and acknowledgment overhead. UDP is the fast cave messenger who throws rocks and hopes they arrive. No connection setup, no guaranteed delivery, no ordering, no congestion control. Packets can arrive out of order, duplicated, or not at all. The benefit? Speed and simplicity. Use TCP when you need reliability: web pages (HTTP), file transfers (FTP), email (SMTP). Use UDP when you need speed and can tolerate loss: video streaming, online gaming, DNS lookups, VoIP. Modern twist: QUIC (used by HTTP/3) builds TCP-like reliability ON TOP of UDP, getting the best of both worlds with faster connection setup and multiplexed streams without head-of-line blocking."),
    msg("user", "what about making sourdough bread?"),
    msg("assistant", "Grug know cave bread well! Sourdough is fermentation magic — no commercial yeast, just wild Lactobacillus bacteria and wild yeast living in symbiosis in your starter. The bacteria produce lactic and acetic acid (the sour), while the yeast produces CO2 (the rise). Basic process: 1) Feed your starter (equal parts flour and water by weight, daily). A healthy starter doubles in 4-6 hours. 2) Mix dough: starter + flour + water + salt. Hydration matters hugely — 70% is manageable for beginners, 80%+ gives open crumb but is harder to handle. 3) Bulk fermentation: 4-12 hours depending on temperature. Stretch and fold every 30 min for first 2 hours to develop gluten without kneading. 4) Shape and cold retard in fridge overnight (12-18 hours). This develops flavor complexity. 5) Bake in a Dutch oven at 500°F covered for 20 min (steam creates crust), then uncovered at 450°F for 20-25 min. The Maillard reaction and caramelization create that gorgeous dark crust. Key insight: sourdough is about managing fermentation, not following exact times. Temperature, humidity, flour type, starter activity — all variables. Learn to read the dough, not the clock."),
    msg("user", "one more thing - explain the trolley problem"),
    msg("assistant", "The Trolley Problem, introduced by Philippa Foot in 1967 and extended by Judith Jarvis Thomson: A runaway trolley is heading toward five people tied to the tracks. You can pull a lever to divert it to a side track, where one person is tied. Do you pull the lever? Most people say yes — save five, sacrifice one. Utilitarian calculus is clear: minimize total harm. But Thomson's variant changes everything: you're on a bridge above the tracks. A large person is next to you. If you push them onto the tracks, their body will stop the trolley, saving the five. Same arithmetic (1 vs 5), but now most people say NO. Why? This is the core puzzle. Deontologists (Kant) say pushing violates the person's dignity — you're using them as a mere means. The lever case feels different because the one person's death is a side effect, not a means. This is the Doctrine of Double Effect. Virtue ethicists ask what kind of person you become by pushing someone to their death. Consequentialists bite the bullet and say push. The trolley problem isn't really about trolleys — it probes our moral intuitions about the difference between doing and allowing, intention and foresight, personal and impersonal harm. It's now crucial in AI ethics: how should self-driving cars make these decisions?", True),
]

# ═══════════════════════════════════════════════════════════════════════
# AROUSAL STATE
# ═══════════════════════════════════════════════════════════════════════

arousal = {
    "level": 0.62,      # Moderately engaged
    "decay_rate": 0.04,
    "baseline": 0.3
}

# ═══════════════════════════════════════════════════════════════════════
# ID COUNTERS
# ═══════════════════════════════════════════════════════════════════════

id_counters = {
    "node_id_counter": NODE_COUNTER[0] + 1,
    "msg_id_counter": MSG_COUNTER[0] + 1
}

# ═══════════════════════════════════════════════════════════════════════
# BRAINSTEM STATE
# ═══════════════════════════════════════════════════════════════════════

brainstem = {
    "dispatch_count": 247,
    "last_winner_id": meta_nodes[4]["id"],  # "who are you" was last winner
    "last_dispatch_t": time.time() - 30.0,
    "propagation_history": [
        {
            "source_lobe_id": "LOBE-META",
            "target_lobe_id": "LOBE-CS",
            "confidence": 0.85,
            "dispatch_count": 42
        },
        {
            "source_lobe_id": "LOBE-CS",
            "target_lobe_id": "LOBE-MATH",
            "confidence": 0.78,
            "dispatch_count": 35
        },
        {
            "source_lobe_id": "LOBE-PHILO",
            "target_lobe_id": "LOBE-PSYCH",
            "confidence": 0.71,
            "dispatch_count": 28
        },
        {
            "source_lobe_id": "LOBE-PHYS",
            "target_lobe_id": "LOBE-MATH",
            "confidence": 0.92,
            "dispatch_count": 51
        },
        {
            "source_lobe_id": "LOBE-BIO",
            "target_lobe_id": "LOBE-FOOD",
            "confidence": 0.65,
            "dispatch_count": 19
        },
        {
            "source_lobe_id": "LOBE-META",
            "target_lobe_id": "LOBE-PHILO",
            "confidence": 0.73,
            "dispatch_count": 31
        },
        {
            "source_lobe_id": "LOBE-ENG",
            "target_lobe_id": "LOBE-PHYS",
            "confidence": 0.81,
            "dispatch_count": 22
        },
        {
            "source_lobe_id": "LOBE-HIST",
            "target_lobe_id": "LOBE-LIT",
            "confidence": 0.68,
            "dispatch_count": 15
        },
    ]
}

# ═══════════════════════════════════════════════════════════════════════
# TRAJECTORY STATE (ActionTonePredictor)
# ═══════════════════════════════════════════════════════════════════════

trajectory = {
    "config": {
        "buffer_size": 16,
        "decay_halflife": 120.0,
        "gini_threshold": 0.72,
        "damping_strength": 0.25,
        "softmax_temperature": 1.5
    },
    "buffer": [
        {
            "action_dist": {
                "ACTION_ASSERT": 0.35, "ACTION_QUERY": 0.10, "ACTION_COMMAND": 0.05,
                "ACTION_NEGATE": 0.05, "ACTION_SPECULATE": 0.25, "ACTION_ESCALATE": 0.20
            },
            "tone_dist": {
                "TONE_HOSTILE": 0.02, "TONE_CURIOUS": 0.30, "TONE_DECLARATIVE": 0.35,
                "TONE_URGENT": 0.03, "TONE_NEUTRAL": 0.15, "TONE_REFLECTIVE": 0.15
            },
            "timestamp": time.time() - 600.0
        },
        {
            "action_dist": {
                "ACTION_ASSERT": 0.40, "ACTION_QUERY": 0.15, "ACTION_COMMAND": 0.03,
                "ACTION_NEGATE": 0.02, "ACTION_SPECULATE": 0.20, "ACTION_ESCALATE": 0.20
            },
            "tone_dist": {
                "TONE_HOSTILE": 0.01, "TONE_CURIOUS": 0.25, "TONE_DECLARATIVE": 0.40,
                "TONE_URGENT": 0.04, "TONE_NEUTRAL": 0.20, "TONE_REFLECTIVE": 0.10
            },
            "timestamp": time.time() - 480.0
        },
        {
            "action_dist": {
                "ACTION_ASSERT": 0.20, "ACTION_QUERY": 0.05, "ACTION_COMMAND": 0.02,
                "ACTION_NEGATE": 0.03, "ACTION_SPECULATE": 0.30, "ACTION_ESCALATE": 0.40
            },
            "tone_dist": {
                "TONE_HOSTILE": 0.00, "TONE_CURIOUS": 0.15, "TONE_DECLARATIVE": 0.20,
                "TONE_URGENT": 0.10, "TONE_NEUTRAL": 0.10, "TONE_REFLECTIVE": 0.45
            },
            "timestamp": time.time() - 360.0
        },
        {
            "action_dist": {
                "ACTION_ASSERT": 0.45, "ACTION_QUERY": 0.08, "ACTION_COMMAND": 0.02,
                "ACTION_NEGATE": 0.05, "ACTION_SPECULATE": 0.15, "ACTION_ESCALATE": 0.25
            },
            "tone_dist": {
                "TONE_HOSTILE": 0.01, "TONE_CURIOUS": 0.20, "TONE_DECLARATIVE": 0.45,
                "TONE_URGENT": 0.02, "TONE_NEUTRAL": 0.12, "TONE_REFLECTIVE": 0.20
            },
            "timestamp": time.time() - 240.0
        },
        {
            "action_dist": {
                "ACTION_ASSERT": 0.30, "ACTION_QUERY": 0.20, "ACTION_COMMAND": 0.05,
                "ACTION_NEGATE": 0.05, "ACTION_SPECULATE": 0.20, "ACTION_ESCALATE": 0.20
            },
            "tone_dist": {
                "TONE_HOSTILE": 0.00, "TONE_CURIOUS": 0.35, "TONE_DECLARATIVE": 0.30,
                "TONE_URGENT": 0.05, "TONE_NEUTRAL": 0.15, "TONE_REFLECTIVE": 0.15
            },
            "timestamp": time.time() - 120.0
        },
    ]
}

# ═══════════════════════════════════════════════════════════════════════
# TEMPORAL COHERENCE LEDGER (ImageSDF)
# ═══════════════════════════════════════════════════════════════════════

# Even though we have no image nodes in this specimen that need it,
# we include a few entries to demonstrate the format
temporal_coherence = [
    {
        "sdf_id": "SDF:neural-network-diagram",
        "last_fired": time.time() - 3600.0,
        "fire_count": 12,
        "avg_interval": 300.0,
        "coherence_score": 0.78
    },
    {
        "sdf_id": "SDF:circuit-schematic",
        "last_fired": time.time() - 7200.0,
        "fire_count": 8,
        "avg_interval": 450.0,
        "coherence_score": 0.65
    },
    {
        "sdf_id": "SDF:molecular-structure",
        "last_fired": time.time() - 1800.0,
        "fire_count": 15,
        "avg_interval": 200.0,
        "coherence_score": 0.85
    },
]

# ═══════════════════════════════════════════════════════════════════════
# MORPH COOLDOWNS (nodes that recently morphed)
# ═══════════════════════════════════════════════════════════════════════

morph_cooldowns = {
    cs_nodes[3]["id"]: time.time() - 3600.0,     # recursion node morphed 1 hour ago
    philo_nodes[4]["id"]: time.time() - 43200.0,  # existentialism morphed 12 hours ago
    meta_nodes[8]["id"]: time.time() - 7200.0,    # joke node morphed 2 hours ago
}

# ═══════════════════════════════════════════════════════════════════════
# ASSEMBLE THE FULL SPECIMEN
# ═══════════════════════════════════════════════════════════════════════

specimen = {
    "nodes": ALL_NODES,
    "hopfield_cache": hopfield_cache,
    "rules": rules,
    "message_history": message_history,
    "lobes": lobes,
    "node_to_lobe_idx": node_to_lobe_idx,
    "lobe_tables": lobe_tables,
    "verb_registry": verb_registry,
    "thesaurus_seeds": thesaurus_seeds,
    "inhibitions": inhibitions,
    "arousal": arousal,
    "id_counters": id_counters,
    "brainstem": brainstem,
    "attachments": attachments,
    "trajectory": trajectory,
    "temporal_coherence": temporal_coherence,
    "morph_cooldowns": morph_cooldowns,
    "_meta": {
        "version": "2.1",
        "saved_at": time.time(),
        "format": "grugbot420-specimen-v2.1"
    }
}

# ═══════════════════════════════════════════════════════════════════════
# SERIALIZE + COMPRESS
# ═══════════════════════════════════════════════════════════════════════

json_str = json.dumps(specimen, indent=2, ensure_ascii=False)
json_bytes = json_str.encode('utf-8')

output_path = "grugbot420_comprehensive.specimen.gz"
with gzip.open(output_path, 'wb', compresslevel=9) as f:
    f.write(json_bytes)

gz_size = os.path.getsize(output_path)
raw_size = len(json_bytes)

# ═══════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════

print("╔══════════════════════════════════════════════════════════════╗")
print("║         🧬 COMPREHENSIVE SPECIMEN GENERATED                ║")
print("╠══════════════════════════════════════════════════════════════╣")
print(f"║  Nodes:              {len(ALL_NODES):>6}                              ║")
print(f"║  Lobes:              {len(lobes):>6}                              ║")
print(f"║  Lobe Tables:        {len(lobe_tables):>6}                              ║")
print(f"║  Hopfield Cache:     {len(hopfield_cache):>6}                              ║")
print(f"║  Rules:              {len(rules):>6}                              ║")
print(f"║  Messages:           {len(message_history):>6}                              ║")
print(f"║  Verb Classes:       {len(verb_registry['classes']):>6}                              ║")
print(f"║  Verb Synonyms:      {len(verb_registry['synonyms']):>6}                              ║")
print(f"║  Thesaurus Seeds:    {len(thesaurus_seeds):>6}                              ║")
print(f"║  Inhibitions:        {len(inhibitions):>6}                              ║")
print(f"║  Attachments:        {len(attachments):>6}                              ║")
print(f"║  Trajectory Entries: {len(trajectory['buffer']):>6}                              ║")
print(f"║  Temporal Coherence: {len(temporal_coherence):>6}                              ║")
print(f"║  Morph Cooldowns:    {len(morph_cooldowns):>6}                              ║")
print(f"║  Graved Nodes:       {sum(1 for n in ALL_NODES if n['is_grave']):>6}                              ║")
print("╠══════════════════════════════════════════════════════════════╣")
print(f"║  Raw JSON:           {raw_size:>10} bytes                    ║")
print(f"║  Compressed:         {gz_size:>10} bytes                    ║")
print(f"║  Compression Ratio:  {raw_size/gz_size:>10.1f}x                       ║")
print(f"║  Format:             v2.1                                  ║")
print("╠══════════════════════════════════════════════════════════════╣")
print(f"║  Output: {output_path:<51}║")
print("╚══════════════════════════════════════════════════════════════╝")