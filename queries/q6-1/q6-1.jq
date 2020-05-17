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

declare function AddPxPyPzE3($particleOne, $particleTwo, $particleThree) {
	let $x := $particleOne.x + $particleTwo.x + $particleThree.x
	let $y := $particleOne.y + $particleTwo.y + $particleThree.y
	let $z := $particleOne.z + $particleTwo.z + $particleThree.z
	let $e := $particleOne.e + $particleTwo.e + $particleThree.e
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

declare function TriJet($particleOne, $particleTwo, $particleThree) {
	PxPyPzE2PtEtaPhiM(
		AddPxPyPzE3(
			PtEtaPhiM2PxPyPzE($particleOne),
			PtEtaPhiM2PxPyPzE($particleTwo),
			PtEtaPhiM2PxPyPzE($particleThree)
			)
		)
};

declare function MakeParticle($event, $jetIdx) {
	{"pt": $event.Jet_pt[[$jetIdx]], "eta": $event.Jet_eta[[$jetIdx]], "phi": $event.Jet_phi[[$jetIdx]], "mass": $event.Jet_mass[[$jetIdx]]}
};

let $bucketWidth := (40 - 15) div 100.0
let $bucketCenter := $bucketWidth div 2

let $loConst := round((15 - $bucketCenter) div $bucketWidth)
let $hiConst := round((40 - $bucketCenter) div $bucketWidth)


let $filtered := (
	for $i in parquet-file("/home/dan/data/garbage/git/rumble-root-queries/data/Run2012B_SingleMu_small.parquet")
		where $i.nJet > 2
		let $triplets := (
				for $iIdx in (1 to (size($i.Jet_pt) - 2))
					return for $jIdx in (($iIdx + 1) to (size($i.Jet_pt) - 1))
								return for $kIdx in (($jIdx + 1) to size($i.Jet_pt))
									let $particleOne := MakeParticle($i, $iIdx)
									let $particleTwo := MakeParticle($i, $jIdx)
									let $particleThree := MakeParticle($i, $kIdx)
									let $triJet := TriJet($particleOne, $particleTwo, $particleThree)

									return {"idx": [$iIdx, $jIdx, $kIdx], "mass": abs(172.5 - $triJet.mass)} 
				)

		let $minMass := min($triplets.mass)

		let $minTriplet := (
			for $j in $triplets
				where $j.mass = $minMass
				return $j
			)

		let $pT := (
			for $j in $minTriplet.idx[]
				return $i.Jet_pt[[$j]]
			)

		return $pT
	)

for $i in $filtered
    let $binned := 
        if ($i < 15) then $loConst
        else
            if ($i < 40) then round(($i - $bucketCenter) div $bucketWidth)
            else $hiConst
    let $x := $binned * $bucketWidth + $bucketCenter
    group by $x
    order by $x
    return {"x": $x, "y": count($i)}