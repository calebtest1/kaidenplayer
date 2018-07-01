(ns kaidenplayer.events
  (:require
    [re-frame.core :as rf]
    [kaidenplayer.db :as db]))

(rf/reg-event-db
  ::db/initialize-db
  (fn [_ _] db/default-db))
