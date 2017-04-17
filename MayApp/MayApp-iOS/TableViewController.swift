//
//  TableViewController.swift
//  MayApp
//
//  Created by Doan Ichikawa on 2017/04/11.
//  Copyright © 2017年 University of Michigan. All rights reserved.
//

import UIKit

class TableViewController: UITableViewController {
    
    let sectionTitle = ["Algorithm","Map Downsize Factor"]
    let settingItem = [["A*"],["32"]]
    var count: Int = 0
    var selection = [Int]()
    var delegate: ViewController? = nil
    
    required init?(coder aDecoder: NSCoder) {
        
        super.init(coder: aDecoder)
        
        count = settingItem.count
        modalPresentationStyle = UIModalPresentationStyle.popover
        var height = 0
        for i in 0...settingItem.count-1 {
            height += settingItem[i].count
        }
        height = (height + 1) * 44
        height += (sectionTitle.count * 30)
        preferredContentSize = CGSize(width: 300, height: height)
        
        selection = [Int](repeating: 0, count: count)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DetailCell")
        self.tableView.backgroundColor = UIColor.lightGray
        
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionTitle[section]
    }
    
    
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {
            cell.accessoryType = .none
        }
        
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row != selection[indexPath.section] {
            
            let oldCell = tableView.cellForRow(at: IndexPath(row: selection[indexPath.section], section: indexPath.section))
            oldCell?.accessoryType = .none
            
            let newCell = tableView.cellForRow(at: indexPath)
            newCell?.accessoryType = .checkmark
            
            selection[indexPath.section] = indexPath.row
        }
    }
    
//    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
//        view.backgroundColor = UIColor.darkGray
//    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sectionTitle.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingItem[section].count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DetailCell", for: indexPath)
        cell.textLabel?.text = settingItem[indexPath.section][indexPath.row]
        cell.accessoryType = (indexPath.row == selection[indexPath.section]) ? .checkmark : .none
        cell.backgroundColor = UIColor.white
        return cell
    }
    

    
    @IBAction func cancelButton() {
        self.dismiss(animated: false, completion: nil)
    }
    
    @IBAction func confirmButton() {

        delegate?.metalView.isPaused = true
//        delegate?.metalView.enableSetNeedsDisplay = true
        delegate?.renderer.findPath(delegate!.metalView, settingItem: settingItem, selection: selection)
        delegate?.renderer.content = .path
        delegate?.metalView.isPaused = false
//        delegate?.metalView.setNeedsDisplay()
        delegate?.cancelNavigationButton.isHidden = false
        self.dismiss(animated: false, completion: nil)
    }


}
