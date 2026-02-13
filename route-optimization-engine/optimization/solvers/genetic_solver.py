"""
Genetic algorithm solver for route optimization.

Uses evolutionary computation to explore the solution space for the
field-service vehicle routing problem. Chromosomes encode a permutation
of work order assignments to technicians, and fitness penalizes
constraint violations while minimizing total travel distance.
"""

from __future__ import annotations

import logging
import random
from copy import deepcopy
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Tuple

from optimization.solvers.base_solver import (
    BaseSolver,
    OptimizationResult,
    RouteStop,
    TechnicianRoute,
)
from optimization.utils.constraints import check_daily_limit, check_skill_match
from optimization.utils.distance import estimate_travel_time

logger = logging.getLogger(__name__)

# Penalty weights for constraint violations in the fitness function.
_SKILL_VIOLATION_PENALTY = 500.0
_TIME_WINDOW_VIOLATION_PENALTY = 200.0
_CAPACITY_VIOLATION_PENALTY = 300.0


@dataclass
class Chromosome:
    """Represents a candidate solution.

    The gene at index ``i`` is the technician index assigned to work
    order ``i``. The ``order_sequence`` list encodes the visitation
    order within each technician's assignments.

    Attributes:
        assignments: List of technician indices, one per work order.
        order_sequence: Permutation of work order indices defining
            intra-route ordering.
        fitness: Cached fitness value (lower is better).
    """

    assignments: List[int]
    order_sequence: List[int]
    fitness: float = float("inf")


class GeneticSolver(BaseSolver):
    """Genetic algorithm solver for field-service routing.

    Uses a permutation-based chromosome encoding with evolutionary
    operators tailored for vehicle routing.

    Config options:
        population_size (int): Number of individuals. Default 100.
        generations (int): Number of generations. Default 500.
        mutation_rate (float): Per-gene mutation probability. Default 0.1.
        elite_size (int): Number of elites carried forward. Default 10.
        tournament_size (int): Tournament selection pool. Default 5.
        seed (int): Random seed for reproducibility. Default None.
        avg_speed_mph (float): Average travel speed. Default 30.
    """

    def solve(self) -> OptimizationResult:
        """Run the genetic algorithm.

        Returns:
            OptimizationResult with the best solution found.
        """
        return self._timed_solve(self._solve_impl)

    def _solve_impl(self) -> OptimizationResult:
        """Core genetic algorithm loop."""
        pop_size = self.config.get("population_size", 100)
        generations = self.config.get("generations", 500)
        mutation_rate = self.config.get("mutation_rate", 0.1)
        elite_size = self.config.get("elite_size", 10)
        tournament_size = self.config.get("tournament_size", 5)
        seed = self.config.get("seed", None)
        avg_speed = self.config.get("avg_speed_mph", 30.0)

        if seed is not None:
            random.seed(seed)

        num_orders = len(self.work_orders)
        num_technicians = len(self.technicians)

        logger.info(
            "GeneticSolver starting: pop=%d, gens=%d, mutation=%.2f, "
            "elite=%d, orders=%d, technicians=%d.",
            pop_size,
            generations,
            mutation_rate,
            elite_size,
            num_orders,
            num_technicians,
        )

        # Build feasibility mask for skill checking
        feasible = self._build_feasibility_mask()

        # Initialize population
        population = self._initialize_population(
            pop_size, num_orders, num_technicians, feasible
        )

        # Evaluate initial fitness
        for chromo in population:
            chromo.fitness = self._evaluate_fitness(chromo, avg_speed)

        population.sort(key=lambda c: c.fitness)
        convergence_history: List[float] = [population[0].fitness]

        logger.debug("Initial best fitness: %.2f", population[0].fitness)

        # Evolution loop
        for gen in range(generations):
            new_population: List[Chromosome] = []

            # Elitism: carry forward best individuals
            elites = deepcopy(population[:elite_size])
            new_population.extend(elites)

            # Generate offspring
            while len(new_population) < pop_size:
                parent1 = self._tournament_select(population, tournament_size)
                parent2 = self._tournament_select(population, tournament_size)

                child1, child2 = self._order_crossover(parent1, parent2)

                self._mutate(child1, mutation_rate, num_technicians, feasible)
                self._mutate(child2, mutation_rate, num_technicians, feasible)

                child1.fitness = self._evaluate_fitness(child1, avg_speed)
                child2.fitness = self._evaluate_fitness(child2, avg_speed)

                new_population.append(child1)
                if len(new_population) < pop_size:
                    new_population.append(child2)

            population = new_population
            population.sort(key=lambda c: c.fitness)
            convergence_history.append(population[0].fitness)

            if (gen + 1) % 100 == 0:
                logger.debug(
                    "Generation %d/%d: best_fitness=%.2f",
                    gen + 1,
                    generations,
                    population[0].fitness,
                )

        best = population[0]
        logger.info("GA converged. Best fitness: %.2f", best.fitness)

        return self._decode_solution(best, avg_speed, convergence_history)

    # ------------------------------------------------------------------
    # Population initialization
    # ------------------------------------------------------------------

    def _initialize_population(
        self,
        pop_size: int,
        num_orders: int,
        num_technicians: int,
        feasible: List[List[bool]],
    ) -> List[Chromosome]:
        """Create the initial random population.

        Assignments prefer skill-feasible technicians when available.

        Args:
            pop_size: Number of individuals.
            num_orders: Number of work orders.
            num_technicians: Number of technicians.
            feasible: Skill-feasibility mask.

        Returns:
            List of randomly initialized Chromosomes.
        """
        population: List[Chromosome] = []
        for _ in range(pop_size):
            assignments: List[int] = []
            for wo_idx in range(num_orders):
                feasible_techs = [
                    v for v in range(num_technicians) if feasible[v][wo_idx]
                ]
                if feasible_techs:
                    assignments.append(random.choice(feasible_techs))
                else:
                    assignments.append(random.randint(0, num_technicians - 1))

            order_sequence = list(range(num_orders))
            random.shuffle(order_sequence)

            population.append(
                Chromosome(assignments=assignments, order_sequence=order_sequence)
            )
        return population

    # ------------------------------------------------------------------
    # Fitness evaluation
    # ------------------------------------------------------------------

    def _evaluate_fitness(self, chromo: Chromosome, avg_speed: float) -> float:
        """Calculate fitness of a chromosome (lower is better).

        Fitness = total travel distance + weighted constraint violation
        penalties.

        Args:
            chromo: Chromosome to evaluate.
            avg_speed: Average travel speed (mph).

        Returns:
            Fitness score.
        """
        num_technicians = len(self.technicians)
        total_distance = 0.0
        penalty = 0.0

        # Group work orders by technician in sequence order
        tech_orders: Dict[int, List[int]] = {v: [] for v in range(num_technicians)}
        for wo_idx in chromo.order_sequence:
            tech_idx = chromo.assignments[wo_idx]
            tech_orders[tech_idx].append(wo_idx)

        for v_idx, wo_indices in tech_orders.items():
            tech = self.technicians[v_idx]
            max_hours = tech.get("max_hours", 8.0)
            shift_start = tech.get("shift_start")
            shift_end = tech.get("shift_end")
            current_node = v_idx
            current_time = shift_start
            used_hours = 0.0

            for wo_idx in wo_indices:
                wo = self.work_orders[wo_idx]
                wo_node = wo_idx + num_technicians

                # Skill violation
                if not self._check_skill_match(tech, wo):
                    penalty += _SKILL_VIOLATION_PENALTY

                # Travel
                dist = self.distance_matrix[current_node][wo_node]
                travel_min = estimate_travel_time(dist, avg_speed)
                service_min = wo.get("duration_minutes", 0)
                total_distance += dist

                # Time window violation
                if current_time is not None:
                    arrival = current_time + timedelta(minutes=travel_min)
                    tw_start = wo.get("time_window_start")
                    tw_end = wo.get("time_window_end")

                    if tw_start and arrival < tw_start:
                        arrival = tw_start  # Wait
                    if tw_end and arrival > tw_end:
                        over_min = (arrival - tw_end).total_seconds() / 60.0
                        penalty += _TIME_WINDOW_VIOLATION_PENALTY * (over_min / 60.0)

                    current_time = arrival + timedelta(minutes=service_min)

                    # Shift end violation
                    if shift_end and current_time > shift_end:
                        over_min = (current_time - shift_end).total_seconds() / 60.0
                        penalty += _CAPACITY_VIOLATION_PENALTY * (over_min / 60.0)

                used_hours += (travel_min + service_min) / 60.0
                current_node = wo_node

            # Daily hour limit
            if used_hours > max_hours:
                penalty += _CAPACITY_VIOLATION_PENALTY * (used_hours - max_hours)

        return total_distance + penalty

    # ------------------------------------------------------------------
    # Selection
    # ------------------------------------------------------------------

    def _tournament_select(
        self, population: List[Chromosome], tournament_size: int
    ) -> Chromosome:
        """Select a parent via tournament selection.

        Args:
            population: Current population (sorted by fitness).
            tournament_size: Number of competitors in each tournament.

        Returns:
            The best Chromosome among the randomly chosen competitors.
        """
        competitors = random.sample(population, min(tournament_size, len(population)))
        return min(competitors, key=lambda c: c.fitness)

    # ------------------------------------------------------------------
    # Crossover
    # ------------------------------------------------------------------

    def _order_crossover(
        self, parent1: Chromosome, parent2: Chromosome
    ) -> Tuple[Chromosome, Chromosome]:
        """Perform Order Crossover (OX) on the sequence component
        and uniform crossover on assignments.

        Args:
            parent1: First parent.
            parent2: Second parent.

        Returns:
            Tuple of two child Chromosomes.
        """
        n = len(parent1.order_sequence)

        # --- Assignment crossover (uniform) ---
        child1_assign = []
        child2_assign = []
        for i in range(n):
            if random.random() < 0.5:
                child1_assign.append(parent1.assignments[i])
                child2_assign.append(parent2.assignments[i])
            else:
                child1_assign.append(parent2.assignments[i])
                child2_assign.append(parent1.assignments[i])

        # --- Order crossover (OX) on sequence ---
        child1_seq = self._ox_sequence(parent1.order_sequence, parent2.order_sequence)
        child2_seq = self._ox_sequence(parent2.order_sequence, parent1.order_sequence)

        return (
            Chromosome(assignments=child1_assign, order_sequence=child1_seq),
            Chromosome(assignments=child2_assign, order_sequence=child2_seq),
        )

    @staticmethod
    def _ox_sequence(seq1: List[int], seq2: List[int]) -> List[int]:
        """Order Crossover (OX) for permutation sequences.

        Selects a random substring from ``seq1`` and fills the remaining
        positions from ``seq2`` in order, preserving relative ordering.

        Args:
            seq1: First parent sequence.
            seq2: Second parent sequence.

        Returns:
            Child sequence (a valid permutation).
        """
        n = len(seq1)
        if n <= 2:
            return list(seq1)

        start = random.randint(0, n - 2)
        end = random.randint(start + 1, n - 1)

        child = [None] * n
        child[start : end + 1] = seq1[start : end + 1]

        inherited = set(seq1[start : end + 1])
        fill_values = [g for g in seq2 if g not in inherited]

        pos = 0
        for val in fill_values:
            while child[pos] is not None:
                pos += 1
            child[pos] = val

        return child

    # ------------------------------------------------------------------
    # Mutation
    # ------------------------------------------------------------------

    def _mutate(
        self,
        chromo: Chromosome,
        mutation_rate: float,
        num_technicians: int,
        feasible: List[List[bool]],
    ) -> None:
        """Apply swap mutation to a chromosome (in-place).

        With probability ``mutation_rate``, each gene in the assignment
        vector is reassigned to a random feasible technician. A random
        pair of elements in the order sequence is swapped.

        Args:
            chromo: Chromosome to mutate.
            mutation_rate: Per-gene mutation probability.
            num_technicians: Number of technicians.
            feasible: Skill-feasibility mask.
        """
        n = len(chromo.assignments)

        # Mutate assignments
        for i in range(n):
            if random.random() < mutation_rate:
                feasible_techs = [v for v in range(num_technicians) if feasible[v][i]]
                if feasible_techs:
                    chromo.assignments[i] = random.choice(feasible_techs)
                else:
                    chromo.assignments[i] = random.randint(0, num_technicians - 1)

        # Mutate sequence (swap two positions)
        if n >= 2 and random.random() < mutation_rate:
            i, j = random.sample(range(n), 2)
            chromo.order_sequence[i], chromo.order_sequence[j] = (
                chromo.order_sequence[j],
                chromo.order_sequence[i],
            )

    # ------------------------------------------------------------------
    # Decode solution
    # ------------------------------------------------------------------

    def _decode_solution(
        self,
        best: Chromosome,
        avg_speed: float,
        convergence_history: List[float],
    ) -> OptimizationResult:
        """Decode the best chromosome into an OptimizationResult.

        Args:
            best: Best chromosome found.
            avg_speed: Average travel speed (mph).
            convergence_history: List of best fitness per generation.

        Returns:
            OptimizationResult with decoded routes.
        """
        num_technicians = len(self.technicians)
        num_orders = len(self.work_orders)

        # Group work orders by technician in sequence order
        tech_orders: Dict[int, List[int]] = {v: [] for v in range(num_technicians)}
        for wo_idx in best.order_sequence:
            tech_idx = best.assignments[wo_idx]
            tech_orders[tech_idx].append(wo_idx)

        routes: List[TechnicianRoute] = []
        total_distance = 0.0
        total_duration = 0.0
        assigned_ids: set = set()

        for v_idx in range(num_technicians):
            tech = self.technicians[v_idx]
            max_hours = tech.get("max_hours", 8.0)
            shift_start = tech.get("shift_start")
            wo_indices = tech_orders[v_idx]

            stops: List[RouteStop] = []
            route_distance = 0.0
            route_duration = 0.0
            route_work_time = 0.0
            current_node = v_idx
            current_time = shift_start
            seq = 0

            for wo_idx in wo_indices:
                wo = self.work_orders[wo_idx]
                wo_node = wo_idx + num_technicians

                # Skip infeasible assignments in final decode
                if not self._check_skill_match(tech, wo):
                    continue

                dist = self.distance_matrix[current_node][wo_node]
                travel_min = estimate_travel_time(dist, avg_speed)
                service_min = wo.get("duration_minutes", 0)

                arrival = current_time + timedelta(minutes=travel_min)
                tw_start = wo.get("time_window_start")
                tw_end = wo.get("time_window_end")

                if tw_start and arrival < tw_start:
                    arrival = tw_start
                if tw_end and arrival > tw_end:
                    continue  # Skip violated time windows in final solution

                departure = arrival + timedelta(minutes=service_min)
                shift_end = tech.get("shift_end")
                if shift_end and departure > shift_end:
                    continue

                total_hours_check = (
                    route_duration + route_work_time + travel_min + service_min
                ) / 60.0
                if total_hours_check > max_hours:
                    continue

                stop = RouteStop(
                    work_order_id=wo["id"],
                    property_id=wo["property_id"],
                    lat=wo["lat"],
                    lng=wo["lng"],
                    sequence=seq,
                    arrival_time=arrival,
                    departure_time=departure,
                    travel_distance=round(dist, 2),
                    travel_duration=round(travel_min, 2),
                )
                stops.append(stop)
                assigned_ids.add(wo["id"])

                route_distance += dist
                route_duration += travel_min
                route_work_time += service_min
                current_node = wo_node
                current_time = departure
                seq += 1

            total_hours = (route_duration + route_work_time) / 60.0
            utilization = (
                min(100.0, (total_hours / max_hours) * 100.0) if max_hours > 0 else 0.0
            )

            routes.append(
                TechnicianRoute(
                    technician_id=tech["id"],
                    technician_name=tech["name"],
                    stops=stops,
                    total_distance=round(route_distance, 2),
                    total_duration=round(route_duration, 2),
                    total_work_time=round(route_work_time, 2),
                    utilization_percent=round(utilization, 1),
                )
            )
            total_distance += route_distance
            total_duration += route_duration

        all_order_ids = {wo["id"] for wo in self.work_orders}
        unassigned = sorted(all_order_ids - assigned_ids)

        return OptimizationResult(
            routes=routes,
            total_distance=round(total_distance, 2),
            total_duration=round(total_duration, 2),
            unassigned_orders=unassigned,
            algorithm="GeneticSolver",
            solve_time_seconds=0.0,
            metadata={
                "best_fitness": round(best.fitness, 4),
                "convergence_history_length": len(convergence_history),
                "initial_fitness": round(convergence_history[0], 4)
                if convergence_history
                else None,
                "final_fitness": round(convergence_history[-1], 4)
                if convergence_history
                else None,
                "improvement_pct": round(
                    (1 - convergence_history[-1] / convergence_history[0]) * 100, 2
                )
                if convergence_history and convergence_history[0] > 0
                else 0.0,
                "num_vehicles_used": sum(1 for r in routes if len(r.stops) > 0),
            },
        )

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    def _build_feasibility_mask(self) -> List[List[bool]]:
        """Build a technician x work_order feasibility matrix."""
        return [
            [
                check_skill_match(tech.get("skills", []), wo.get("required_skills", []))
                for wo in self.work_orders
            ]
            for tech in self.technicians
        ]
