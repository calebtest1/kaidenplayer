(ns kaidenplayer.core
  (:require
   [reagent.core :as reagent]
   [re-frame.core :as re-frame]
   [kaidenplayer.config :as config]
   [kaidenplayer.db :as db]
   [kaidenplayer.events]
   [kaidenplayer.subs]))

(defn main-panel []
  [:h1 "Welcome to Re-Frame"])

(defn dev-setup []
  (when config/debug?
    (enable-console-print!)
    (println "dev mode")))

(defn mount-root []
  (re-frame/clear-subscription-cache!)
  (reagent/render [main-panel]
                  (.getElementById js/document "app")))

(defn ^:export init []
  (re-frame/dispatch-sync [::db/initialize-db])
  (dev-setup)
  (mount-root))
