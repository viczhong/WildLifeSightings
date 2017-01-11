//
//  SightingsViewController.swift
//  WildlifeSighting
//
//  Created by Sabrina Ip on 1/9/17.
//  Copyright © 2017 Sabrina, Vic, Tom. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit
import CoreData

class SightingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CLLocationManagerDelegate, MKMapViewDelegate, NSFetchedResultsControllerDelegate {
    
    
    // MARK: - Outlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var mapOrDataSegmentedControl: UISegmentedControl!
    @IBOutlet weak var tableViewBottomLayoutConstraint: NSLayoutConstraint!
    
    
    // MARK: - Properties
    
    var mainContext: NSManagedObjectContext {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.persistentContainer.viewContext
    }
    var fetchedResultsController: NSFetchedResultsController<Sighting>!
    
    // MARK: - viewDidLoad and setUp
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setToolbarHidden(true, animated: false)
        setDelegates()
        setUpTableView()
        initializeFetchedResultsController()
        setMapPins()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setToolbarHidden(true, animated: false)
        setMapPins()
    }
    
    
    func setUpTableView() {
        self.tableView.register(UINib(nibName: "SightingTableViewCell", bundle: nil), forCellReuseIdentifier: "SightingTableViewCell")
        tableView.estimatedRowHeight = 300
        tableView.rowHeight = UITableViewAutomaticDimension
    }
    
    func setDelegates() {
        tableView.delegate = self
        tableView.dataSource = self
        mapView.delegate = self
    }
    
    func setMapPins() {
        if let sightings = fetchedResultsController.fetchedObjects {
            for object in sightings {
                let pinAnnotation = SightingMKPointAnnotation()
                pinAnnotation.title = object.name
                pinAnnotation.subtitle = object.dateAndTime
                pinAnnotation.coordinate = object.location.coordinate
                pinAnnotation.managedObject = object
                mapView.addAnnotation(pinAnnotation)
            }
        }
    }
    
    
    
    @IBAction func mapOrDataSegmentedControlChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            mapView.isHidden = false
            tableViewBottomLayoutConstraint.isActive = false
            tableViewBottomLayoutConstraint = tableView.bottomAnchor.constraint(equalTo: self.view.centerYAnchor)
            tableViewBottomLayoutConstraint.isActive = true

        case 1:
            mapView.isHidden = true
            tableViewBottomLayoutConstraint.isActive = false
            tableViewBottomLayoutConstraint = tableView.bottomAnchor.constraint(equalTo: mapOrDataSegmentedControl.topAnchor, constant: -8.0)
            tableViewBottomLayoutConstraint.isActive = true
        default:
            break
        }
    }
    
    
    // MARK: - Initialize Fetched Results Controller
    
    func initializeFetchedResultsController() {
        let request: NSFetchRequest<Sighting> = Sighting.fetchRequest()
        let dateSort = NSSortDescriptor(key: #keyPath(Sighting.date), ascending: false)
        request.sortDescriptors = [dateSort]
        let sectionName = "dateString"

        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: mainContext, sectionNameKeyPath: sectionName, cacheName: nil)
        fetchedResultsController.delegate = self
        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError("Failed to initialize FetchedResultsController: \(error)")
        }
    }
    
    
    
    // MARK: - mapView delegate methods
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if let myAnnotation = view.annotation as? SightingMKPointAnnotation,
            let myObject = myAnnotation.managedObject,
            let indexPath = fetchedResultsController.indexPath(forObject: myObject) {
            tableView.scrollToRow(at: indexPath, at: .top, animated: true)
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .top)
        }
    }

    
    
    
    // MARK: - tableView delegate methods
    
    func numberOfSections(in tableView: UITableView) -> Int {
        guard let sections = fetchedResultsController.sections else { fatalError("No sections in fetched results controller")}
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sections = fetchedResultsController.sections else {
            fatalError("No sections in fetchedResultsController")
        }
        let sectionInfo = sections[section]
        return sectionInfo.numberOfObjects
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sections = fetchedResultsController.sections else {
            fatalError("No sections in fetched results controller")
        }
        let sectionInfo = sections[section]
        return sectionInfo.name
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SightingTableViewCell", for: indexPath) as! SightingTableViewCell
        let object = fetchedResultsController.object(at: indexPath)
        cell.sightingTitleLabel.text = object.name!
        cell.sightingDateAndTimeLabel.text = object.dateAndTime
        
        if let thumbData = object.thumbImageData as? Data {
            cell.sightingImageView?.image = UIImage(data: thumbData)
        } else {
            cell.sightingImageView.image = #imageLiteral(resourceName: "noImage")
        }
        
        cell.infoButton.addTarget(self, action: #selector(self.buttonTapped(_:)), for: UIControlEvents.touchUpInside)

        return cell
    }
    

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true // return true to be able to delete things - the default is false
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let object = fetchedResultsController.object(at: indexPath)
            mainContext.delete(object)
            do {
                try mainContext.save()
            } catch let error {
                fatalError("Failed to save context: \(error)")
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let object = fetchedResultsController.object(at: indexPath)
        let validLocation = CLLocation(latitude: object.latitude, longitude: object.longitude)
        mapView.setRegion(MKCoordinateRegionMakeWithDistance(validLocation.coordinate, 5000.0, 5000.0), animated: true)

        for annotaion in mapView.annotations {
            if let myAnnotaion = annotaion as? SightingMKPointAnnotation {
                if myAnnotaion.managedObject == object {
                    mapView.selectAnnotation(myAnnotaion, animated: true)
                }
            }
        }
    }
    
    //MARK: - NSFetchedResultsController Delegate Methods
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            tableView.insertSections(IndexSet(integer: sectionIndex), with: .automatic)
        case .delete:
            tableView.deleteSections(IndexSet(integer: sectionIndex), with: .automatic)
        case .move:
            break
        case .update:
            break
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .automatic)
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .automatic)
        case .update:
            tableView.reloadRows(at: [indexPath!], with: .automatic)
        case .move:
            tableView.moveRow(at: indexPath!, to: newIndexPath!)
        }
    }

    func buttonTapped(_ sender:UIButton!){
        self.performSegue(withIdentifier: "SegueToDetailsVC", sender: sender)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "SegueToDetailsVC" {
            guard let destination = segue.destination as? SightingDetailsViewController,
                let button = sender as? UIButton,
                let superview = button.superview,
                let cell = superview.superview as? SightingTableViewCell else { return }
            let indexPath = tableView.indexPath(for: cell)
            destination.sightingID = fetchedResultsController.object(at: indexPath!).objectID
            destination.sightingIndexPath = indexPath
        }
    }
    
}


