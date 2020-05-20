declare function histogramConsts($loBound, $hiBound, $binCount) {
    let $bucketWidth := ($hiBound - $loBound) div $binCount
    let $bucketCenter := $bucketWidth div 2

    let $loConst := round(($loBound - $bucketCenter) div $bucketWidth)
    let $hiConst := round(($hiBound - $bucketCenter) div $bucketWidth)

    return {"bins": $binCount, "width": $bucketWidth, "center": $bucketCenter, "loConst": $loConst, "hiConst": $hiConst,
            "loBound": $loBound, "hiBound": $hiBound}
};

declare function sinh($x) {
	(exp($x) - exp(-$x)) div 2.0
};

declare function cosh($x) {
	(exp($x) + exp(-$x)) div 2.0
};

declare function PtEtaPhiM2PxPyPzE($vect) {
	let $x := $vect.pt * cos($vect.phi)
	let $y := $vect.pt * sin($vect.phi)
	let $z := $vect.pt * sinh($vect.eta)
	let $temp := $vect.pt * cosh($vect.eta)
	let $e := $temp * $temp + $vect.mass * $vect.mass
	return {"x": $x, "y": $y, "z": $z, "e": $e}
};

declare function AddPxPyPzE2($particleOne, $particleTwo) {
	let $x := $particleOne.x + $particleTwo.x
	let $y := $particleOne.y + $particleTwo.y
	let $z := $particleOne.z + $particleTwo.z
	let $e := $particleOne.e + $particleTwo.e
	return {"x": $x, "y": $y, "z": $z, "e": $e}
};

declare function RhoZ2Eta($rho, $z) {
	let $temp := $z div $rho
	return log($temp + sqrt($temp * $temp + 1.0))
};

declare function PxPyPzE2PtEtaPhiM($particle) {
	let $sqX := $particle.x * $particle.x
	let $sqY := $particle.y * $particle.y
	let $sqZ := $particle.z * $particle.z
	let $sqE := $particle.e * $particle.e

	let $pt := sqrt($sqX + $sqY)
	let $eta := RhoZ2Eta($pt, $particle.z)
	let $phi := if ($particle.x = 0.0 and $particle.y = 0.0)
				then 0.0
				else atan2($particle.y, $particle.x)
	let $mass := sqrt($sqE - $sqZ - $sqY - $sqX)

	return {"pt": $pt, "eta": $eta, "phi": $phi, "mass": $mass}
};

declare function AddPtEtaPhiM2($particleOne, $particleTwo) {
	PxPyPzE2PtEtaPhiM(
		AddPxPyPzE2(
			PtEtaPhiM2PxPyPzE($particleOne),
			PtEtaPhiM2PxPyPzE($particleTwo)
			)
		)
};

declare function DeltaPhi($phi1, $phi2) {
	($phi1 - $phi2 + pi()) mod (2 * pi()) - pi()
};

declare function ConcatLeptons($event) {
	let $nLepton := $event.nMuon + $event.nElectron
	let $pt := ($event.Muon_pt[], $event.Electron_pt[])
	let $eta := ($event.Muon_eta[], $event.Electron_eta[])
	let $phi := ($event.Muon_phi[], $event.Electron_phi[])
	let $mass := ($event.Muon_mass[], $event.Electron_mass[])
	let $charge := ($event.Muon_charge[], $event.Electron_charge[])

	let $m := for $i in (1 to size($event.Muon_pt)) return "m"
	let $e := for $i in (1 to size($event.Electron_pt)) return "e"

	let $type := ($m, $e)

	return {"nLepton": $nLepton, "pt": $pt, "eta": $eta, "phi": $phi, "mass": $mass, "charge": $charge, "type": $type}
};

declare function MakeParticle($event, $idx) {
	{"pt": $event.pt[[$idx]], "eta": $event.eta[[$idx]], "phi": $event.phi[[$idx]], "mass": $event.mass[[$idx]]}
};

let $dataPath := "/home/dan/data/garbage/git/rumble-root-queries/data/Run2012B_SingleMu_small.parquet"
let $histogram := histogramConsts(15, 250, 100)


let $filtered := (
	for $i in parquet-file($dataPath)
	where ($i.nMuon + $i.nElectron) > 2 
	let $leptons := ConcatLeptons($i)

	let $pairs := (
		for $iIdx in (1 to (size($leptons.pt) - 1))
			return for $jIdx in (($iIdx + 1) to size($leptons.pt))
				where $leptons.type[[$iIdx]] = $leptons.type[[$jIdx]] and $leptons.charge[[$iIdx]] != $leptons.charge[[$jIdx]]
				let $particleOne := MakeParticle($leptons, $iIdx)
				let $particleTwo := MakeParticle($leptons, $jIdx)
				return {"i": $iIdx, "j": $jIdx, "mass": abs(91.2 - AddPtEtaPhiM2($particleOne, $particleTwo).mass)}
	)
	where exists($pairs)

	let $minMass := min($pairs.mass)
	let $minPair := (
		for $j in $pairs
		where $j.mass = $minMass
		return $j
	)

	let $maxOtherPt := max(
		for $j in (1 to size($leptons.pt))
		where $j != $minPair.i and $j != $minPair.j
		return $leptons.pt[[$j]]
	)

	let $otherLeptonMass := (
		for $j in (1 to size($leptons.pt))
		where $j != $minPair.i and $j != $minPair.j and $leptons.pt[[$j]] = $maxOtherPt
		let $transverseMass := 2 * $i.MET_pt * $maxOtherPt * (1.0 - cos(DeltaPhi($i.MET_phi, $leptons.phi[[$j]])))
		return $transverseMass
	)

	return $otherLeptonMass
)


for $i in $filtered
let $y :=   if ($i < $histogram.loBound) 
            then $histogram.loConst
            else
                if ($i < $histogram.hiBound)
                then round(($i - $histogram.center) div $histogram.width)
                else $histogram.hiConst
let $x := $y * $histogram.width + $histogram.center
group by $x
order by $x
return {"x": $x, "y": count($i)}