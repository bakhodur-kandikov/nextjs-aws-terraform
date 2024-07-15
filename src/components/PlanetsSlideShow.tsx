"use client"

import Image from "next/image";
import { useEffect, useState } from "react";

const slideTimeoutInMS = 2000;

type CapitalizeString<T extends string> = Capitalize<T>
type PlanetName = "earth" | "jupiter" | "moon" | "venus";
type PlanetNameWithExtension = `${PlanetName}.jpeg`;
type PlanetMapValue = {
    fileName: PlanetNameWithExtension,
    name: CapitalizeString<PlanetName>
}

const planetsMap = new Map<number, PlanetMapValue>([
    [0, {fileName: "earth.jpeg", name: "Earth"}],
    [1, {fileName: "jupiter.jpeg", name: "Jupiter"}],
    [2, {fileName: "moon.jpeg", name: "Moon"}],
    [3, {fileName: "venus.jpeg", name: "Venus"}],
]);

export const PlanetsSlideShow = () => {
    const [slideIndex, setSlideIndex] = useState(0);

    useEffect(() => {
        const lastSlideIndex = planetsMap.size - 1;
        const timeout = setTimeout(() => {
            setSlideIndex((prev) => prev === lastSlideIndex ? 0 : prev + 1)
        }, slideTimeoutInMS);

        return () => clearTimeout(timeout)
    }, [slideIndex]);

    const currentPlanet = planetsMap.get(slideIndex)!;

    return <div>
        <p className="text-black text-center">{currentPlanet.name}</p>
        <Image
            className="relative dark:drop-shadow-[0_0_0.3rem_#ffffff70] dark:invert"
            src={currentPlanet.fileName}
            alt={currentPlanet.name}
            width={500}
            height={500}
            priority
        />
    </div>
}
