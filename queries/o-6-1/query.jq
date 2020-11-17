import module namespace hep = "../common/hep.jq";
import module namespace o-6 = "../o-6/common.jq";
declare variable $dataPath as anyURI external := anyURI("../../data/Run2012B_SingleMu.root");

let $filtered :=
  for $event in hep:RestructureDataParquet($dataPath)
  where $event.nJet > 2
  return o-6:find-min-triplet($event).pt

return hep:histogram($filtered, 15, 40, 100)
